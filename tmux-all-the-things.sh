#!/bin/sh
set -eu

. ./.env

tmux has-session || tmux new-session -d
tmux list-windows -f '#{m:mtr,#W}' | grep -q . || tmux new-window -n mtr mmtr $REMOTE
tmux list-windows -f '#{m:stream,#W}' | grep -q . || tmux new-window -n stream nnload
tmux select-window -t stream
tmux list-panes | wc -l | grep -q ^1$ && tmux split-window -v -b -l 10
#pidof -sq ffmpeg || tmux new-window -n kiyo kiyo.sh
[ "$TMUX" ] || tmux attach
