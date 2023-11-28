#!/bin/sh
set -e -o pipefail

# Create a virtual output if one doesn't already exist
if swaymsg -rt get_outputs | jq -r .[].name | grep -wq HEADLESS-1; then
  echo "Virtual output HEADLESS-1 already exists."
else
  echo "Virtual output HEADLESS-1 doesn't exist. Creating it."
  swaymsg create_output
fi

# Figure out the outputs of LEFT and RIGHT monitors
LEFT=$(swaymsg -rt get_outputs  | jq -r '.[] | select(.rect.x == 0) .name')
RIGHT=$(swaymsg -rt get_outputs  | jq -r '.[] | select(.rect.x == 3840) .name')
VIRTUAL=HEADLESS-1

# Move desktops to their appropriate outputs
while read WORKSPACE OUTPUT DESC; do
  echo "Moving workspace $WORKSPACE to output $OUTPUT ($DESC)."
  swaymsg "workspace $WORKSPACE; move workspace to output $OUTPUT"
done <<EOF
1 $VIRTUAL VIRTUAL
2 $VIRTUAL VIRTUAL
3 $VIRTUAL VIRTUAL
4 $VIRTUAL VIRTUAL
5 $VIRTUAL VIRTUAL
6 $LEFT LEFT
7 $LEFT LEFT
8 $RIGHT RIGHT
9 $LEFT LEFT
10 $LEFT LEFT
11 $RIGHT RIGHT
EOF
