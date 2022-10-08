#!/bin/sh
for MONITOR in TOP BOTTOM LEFTHALF; do
  xrandr --delmonitor $MONITOR
done

move_workspace() {
  WORKSPACE=$1
  OUTPUT=$2
  echo "Moving workspace $WORKSPACE to output $OUTPUT."
  i3-msg "workspace $WORKSPACE; move workspace to output $OUTPUT"
}

LEFT=$(xrandr -q | grep 3840x2160+0+0 | cut -d" " -f1)
RIGHT=$(xrandr -q | grep 3840x2160+3840+0 | cut -d" " -f1)

if [ "$LEFT" ]; then
  for WS in 6 7 10 9; do move_workspace $WS $LEFT; done
fi
if [ "$RIGHT" ]; then
  for WS in 1 2 3 4 5 8; do move_workspace $WS $RIGHT; done
  i3-msg "workspace 8; layout splith"
fi
