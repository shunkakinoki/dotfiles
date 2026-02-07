#!/usr/bin/env bash
# Toggle screen recording with wf-recorder

PIDFILE=/tmp/wf-recorder.pid
OUTDIR="$HOME/Videos"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")"
  rm -f "$PIDFILE"
  notify-send "Screen Recording" "Recording saved to $OUTDIR"
else
  mkdir -p "$OUTDIR"
  FILENAME="$OUTDIR/recording-$(date +%Y%m%d-%H%M%S).mp4"
  GEOMETRY=$(slurp)
  if [ -n "$GEOMETRY" ]; then
    wf-recorder -g "$GEOMETRY" -f "$FILENAME" &
    echo $! >"$PIDFILE"
    notify-send "Screen Recording" "Recording started..."
  fi
fi
