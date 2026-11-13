#!/bin/sh
# krieger: keep the home screen's Earth picture and weather fresh.
# Every 15 min: the GOES-West GeoColor full-disk picture (NOAA, public domain),
# which also supplies the live clouds, and an Open-Meteo forecast for home.
# Once: NASA's day map and night lights (GIBS).
# A failed or odd download keeps the last good file.
OUT=/var/lib/webosbrew/homeqml-k/qml/earth
IMG=https://cdn.star.nesdis.noaa.gov/GOES18/ABI/FD/GEOCOLOR/1808x1808.jpg
LAT=39.74     # set to your home
LON=-104.99   # set to your home
WX="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,precipitation_probability,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max&temperature_unit=fahrenheit&timezone=auto&forecast_days=8"
GIBS="https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&CRS=EPSG:4326"
DAY="$GIBS&LAYERS=BlueMarble_NextGeneration&BBOX=-90,-180,90,180&WIDTH=2048&HEIGHT=1024&FORMAT=image/jpeg"
NIGHT="$GIBS&LAYERS=VIIRS_Black_Marble&BBOX=-90,-180,90,180&WIDTH=2048&HEIGHT=1024&FORMAT=image/jpeg"
PIDFILE=/tmp/earthfetch-k.pid

# one copy only
if [ -f $PIDFILE ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then exit 0; fi
echo $$ > $PIDFILE

# fetch URL DEST MIN_BYTES MAX_BYTES KIND(jpeg|json): download to a tmp file,
# keep it only if the size is sane and it really is that kind of file
fetch() {
  tmp=$2.tmp
  rm -f $tmp
  if curl -sf -m 300 --max-filesize $4 -o $tmp "$1"; then
    size=$(wc -c < $tmp)
    ok=0
    [ "$size" -ge $3 ] && [ "$size" -le $4 ] && ok=1
    if [ $ok = 1 ] && [ $5 = jpeg ]; then
      [ "$(head -c 3 $tmp | od -An -tx1 | tr -d ' \n')" = "ffd8ff" ] || ok=0
    fi
    if [ $ok = 1 ] && [ $5 = json ]; then
      grep -q '"hourly"' $tmp || ok=0
    fi
    [ $ok = 1 ] && mv $tmp $2
  fi
  rm -f $tmp
}

mkdir -p $OUT
while true; do
  # the NASA maps don't change: fetched until we have them
  [ -s $OUT/day.jpg ] || fetch "$DAY" $OUT/day.jpg 50000 5000000 jpeg
  [ -s $OUT/night.jpg ] || fetch "$NIGHT" $OUT/night.jpg 30000 5000000 jpeg
  fetch "$IMG" $OUT/earth.jpg 300000 5000000 jpeg
  fetch "$WX" $OUT/weather.json 500 1000000 json
  sleep 900
done
