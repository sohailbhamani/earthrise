#!/bin/sh
# krieger: reconnect an LG soundbar over Bluetooth and route sound to it
# on every TV power-on (cold boot or wake from standby).
BAR=AA:BB:CC:DD:EE:FF   # your soundbar's Bluetooth address (see device/getStatus)
LOG=/tmp/soundbar-k.log
PIDFILE=/tmp/soundbar-k.pid

# one copy only
if [ -f $PIDFILE ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then exit 0; fi
echo $$ > $PIDFILE

reconnect() {
  sleep 8
  for try in 1 2 3 4 5 6; do
    luna-send -n 1 luna://com.webos.service.bluetooth2/a2dp/connect "{\"address\":\"$BAR\"}" >/dev/null 2>&1
    sleep 5
    if luna-send -n 1 luna://com.webos.service.bluetooth2/a2dp/getStatus "{\"address\":\"$BAR\"}" 2>/dev/null | grep -q '"connected": *true'; then
      luna-send -n 1 luna://com.webos.service.settings/setSystemSettings '{"category":"sound","settings":{"soundOutput":"bt_soundbar"}}' >/dev/null 2>&1
      echo "$(date) connected (try $try)" >> $LOG
      return
    fi
  done
  echo "$(date) soundbar not reachable, left output alone" >> $LOG
}

# the subscription's first reply is the current state, so a cold boot
# (Active straight away) gets a reconnect too
prev=
luna-send -i luna://com.webos.service.tvpower/power/getPowerState '{"subscribe":true}' 2>/dev/null |
while read -r line; do
  state=$(echo "$line" | sed -n 's/.*"state": *"\([^"]*\)".*/\1/p')
  [ -z "$state" ] && continue
  if [ "$state" = "Active" ]; then
    case "$prev" in
      Active|"Screen Saver"|"Screen Off") ;;
      *) reconnect & ;;
    esac
  fi
  prev=$state
done
