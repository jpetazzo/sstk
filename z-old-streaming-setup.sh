move_workspace() {
  WORKSPACE=$1
  OUTPUT=$2
  i3-msg "workspace $WORKSPACE; move workspace to output $OUTPUT"
}

find_output() {
  OUTPUT=$(xrandr -q | grep $1 | head -n 1 | cut -d" " -f1)
  [ "$OUTPUT" ] || {
    echo "Couldn't find an output matching '$1'. Aborting."
    exit 1
  }
  echo "$OUTPUT"
}

streaming_setup() {
  # Main screen. Keep it as is.
  OUTPUT_MAIN=$(find_output 3840x2160+0+0)
  # Presenter side screen. Will be split in 3.
  OUTPUT_SIDE=$(find_output 3840x2160+3840+0)
  # Video encoder output.
  OUTPUT_STREAM=$(find_output 1920x1080+5760+1080)

  # Dimensions of the side screen.
  W_MM=698
  H_MM=393
  W_PX=3840
  H_PX=2160
  # Position of the side screen in the framebuffer.
  X=3840
  Y=0

  # Name the main monitor.
  xrandr --setmonitor MAIN \
    $(($W_PX/1))/$(($W_MM/1))x$(($H_PX/1))/$(($H_MM/1))+0+0 ${OUTPUT_MAIN}

  # Create a virtual monitor, to be captured by OBS.
  xrandr --setmonitor PRESENTER \
    $(($W_PX/2))/$(($W_MM/2))x$(($H_PX/2))/$(($H_MM/2))+$(($X+$W_PX/2))+$Y none
  # Create a monitor with the remaining half of the side screen.
  xrandr --setmonitor SIDE \
    $(($W_PX/2))/$(($W_MM/2))x$(($H_PX/1))/$(($H_MM/1))+$(($X        ))+$Y ${OUTPUT_SIDE}

  # Create a workspace dedicated to OBS output on the encoder output.
  i3-msg "workspace 11; move workspace to output $OUTPUT_STREAM"

  # Move workspaces 1-4 to the workspace used for presentation.
  move_workspace 1 PRESENTER
  move_workspace 2 PRESENTER
  move_workspace 3 PRESENTER
  move_workspace 4 PRESENTER

  # Move workspaces 8(chat) and 10(obs) to side screen.
  move_workspace 8 SIDE
  move_workspace 10 SIDE

  # Move other workspaces to main screen.
  move_workspace 5 MAIN
  move_workspace 6 MAIN
  move_workspace 7 MAIN
  move_workspace 9 MAIN
}

streaming_setup
