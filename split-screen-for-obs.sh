#!/bin/sh

# The goal of this script is to split a real monitor into multiple virtual
# monitors, one of which will be used for screen grabbing by OBS.

# Before:
# +---------------------------------+
# |                                 |
# |                                 |
# |                                 |
# |                                 |
# |        original screen          |
# |             (4K)                |
# |                                 |
# |                                 |
# |                                 |
# +---------------------------------+
#
# After:
# +----------------+----------------+
# |                |                |
# |                |   top half     |
# |                | (OBS capture)  |
# |                |     1080p      |
# |   left pane    +----------------+
# |                |                |
# |                |  bottom half   |
# |                | (OBS control)  |
# |                |     1080p      |
# +----------------+----------------+
#
# This can also be used on a 1920x2160 monitor to obtain just the top and
# bottom panes (without the left pane shown above). This is intended to be
# used with PBP (Picture-By-Picture) monitors, when only one half of the
# monitor is used.


W_MM=$((698/2))
H_MM=$((393/2))

W_PX=1920
H_PX=1080

do_the_thing() {
  xrandr --delmonitor TOP || true
  xrandr --delmonitor BOTTOM || true
  xrandr --setmonitor TOP \
    ${W_PX}/${W_MM}x${H_PX}/${H_MM}+${W_OFFSET}+0 $TOP_OUTPUT
  xrandr --setmonitor BOTTOM \
    ${W_PX}/${W_MM}x${H_PX}/${H_MM}+${W_OFFSET}+$H_PX $BOTTOM_OUTPUT
}

move_workspace() {
  WORKSPACE=$1
  OUTPUT=$2
  i3-msg "workspace $WORKSPACE; move workspace to output $OUTPUT"
}

# Let's check if there is a 4K monitor to the right.
# (i.e. positioned at (3840,0))
OUTPUT=$(xrandr -q | grep 3840x2160+3840+0 | cut -d" " -f1)
if [ "$OUTPUT" ]; then
  W_OFFSET=$((3*1920))
  TOP_OUTPUT=none
  BOTTOM_OUTPUT=none
  do_the_thing

  # Assign the left half of the screen too
  xrandr --delmonitor LEFT || true
  xrandr --setmonitor LEFT \
    ${W_PX}/${W_MM}x$((2*${H_PX}))/$((2*${H_MM}))+$((2*1920))+0 $OUTPUT

  for WS in 1 2 3 4; do move_workspace $WS TOP; done
  exit 0
fi

# Let's check if we have a 1920x2160 main screen.
# If so, split it top and bottom.
OUTPUT=$(xrandr -q | grep 1920x2160+0+0 | cut -d" " -f1)
if [ "$OUTPUT" ]; then
  # When I have an output named HDMI-0, I'm with a single display,
  # in PBP, with 1920x2160 resolution. Split it top and bottom.
  W_OFFSET=0
  TOP_OUTPUT=$OUTPUT
  BOTTOM_OUTPUT=none
  do_the_thing

  for WS in 1 2 3 4; do move_workspace $WS TOP; done
  for WS in 5 6 7 8 9 10; do move_workspace $WS BOTTOM; done

  # This is unrelated to screen splitting, but it is seems to be
  # necessary for my VNC client (remmina) to correctly pass the
  # compose key. It looks like I only need to do it once, and it
  # sticks when reconnecting.
  setxkbmap -option ralt:compose
  exit 0
fi

echo "Could not find any recognized monitor arrangement. Sorry."
