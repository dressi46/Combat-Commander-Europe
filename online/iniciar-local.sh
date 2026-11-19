#!/bin/sh
set -eu
cd "$(dirname "$0")"
LOBBY_BIND=127.0.0.1 PORT=8790 ./linux/CombatCommander --headless -- --lobby-server &
server_pid=$!
python3 -m http.server 8780 --bind 127.0.0.1 --directory web &
web_pid=$!
trap 'kill "$server_pid" "$web_pid" 2>/dev/null || true' EXIT
trap 'exit 0' INT TERM
sleep 1
kill -0 "$server_pid" "$web_pid"
echo 'Combat Commander · http://localhost:8780'
wait "$server_pid"
