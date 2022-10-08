#!/bin/sh
tmux has-session || tmux new-session -d
pidof -sq nload || tmux new-window -n nload nnload
pidof -sq mtr || tmux new-window -n mtr mmtr
pidof -sq ffmpeg || tmux new-window -n kiyo kiyo.sh
tmux new-window
tmux attach
