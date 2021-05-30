# This adds a virtual screen "off screen" (it doesn't correspond to any real
# monitor). The goal is to have a bunch of "free pixels" to put some windows
# (e.g. a terminal, a browser...) that will then be grabbed by OBS or by some
# screen sharing system.

# Unfortunately, this doesn't work very well, because Xorg prevents the
# mouse pointer from going to that off screen area.

add_virtual_screen_below() {
  # get fb size WxH
  W=4000
  H=2640

  xrandr --fb ${W}x$((${H}+1080))
  xrandr --setmonitor VIRTUAL 1920/332x1080/187+0+$H none

  ffmpeg -video_size 1920x1080 -framerate 30 \
    -f x11grab -i :0.0+0,$H xv
}

add_virtual_screen_to_the_right() {
  W=7040
  H=1440

  xrandr --fb $((${W}+1920))x${H}
  xrandr --setmonitor VIRTUAL 1920/332x1080/187+${W}+0 none
  ffmpeg -video_size 1920x1080 -framerate 30 \
    -f x11grab -i :0.0+$W,0 xv
}

