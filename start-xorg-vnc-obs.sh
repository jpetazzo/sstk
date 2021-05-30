#!/bin/sh

# This will start:
# - an Xorg server
# - a VNC server (x0vncserver from the tigervnc package)
# - OBS
# The three processes will be started in tmux, for convenience.
# They will only be started if they're not already running.

echo -n "Looking for Xorg PID: "
if ! pidof Xorg; then
  echo "not found."
  echo "Starting Xorg."
  sudo chown $USER /dev/tty10
  tmux new-window \
    startx -- vt10
fi

echo "Waiting for X server to be up and running..."
export DISPLAY=:0
while ! xhost; do
  sleep 1
done

echo -n "Looking for x0vncserver PID: "
if ! pidof x0vncserver; then
  echo "not found."
  echo "Starting x0vncserver."
  tmux new-window \
    x0vncserver -display :0 \
    -AcceptSetDesktopSize=off \
    -AlwaysShared=on \
    -FrameRate=10 \
    -Geometry=1920x2160+0+0 \
    -PasswordFile=$HOME/.vnc/passwd \
    #
fi

echo -n "Looking for OBS PID: "
if ! pidof obs; then
  echo "not found."
  echo "Starting OBS."
  tmux new-window \
    env DISPLAY=:0 obs \
    --startvirtualcam
fi

# For reference, this can be used as an alternate VNC server:
#x11vnc -clip 1920x1080+0+0 -display :0 -nocursorshape
# (I found tigervnc to offer better performance and behavior, though,
# in particular when updating/repainting the OBS video preview.)

# And this can be used to start a fully headless VNC server:
#Xvnc :1 -geometry 1920x2160 -AcceptSetDesktopSize=off -FrameRate=30 -SecurityTypes=None -AlwaysShared=on
# (It works but will require *a lot* of CPU power since it won't be
# able to leverage any kind of GPU acceleration for video decoding
# and compositing.)

