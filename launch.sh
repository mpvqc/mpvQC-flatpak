#!/usr/bin/env sh

cd "/app/share/io.github.mpvqc.mpvQC" || exit
exec /app/bin/mpvQC-bin "/app/share/io.github.mpvqc.mpvQC/main.py" "$@"
