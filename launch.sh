#!/usr/bin/env sh

cd "/app/my-app" || exit
python "/app/my-app/main.py" "$@"
