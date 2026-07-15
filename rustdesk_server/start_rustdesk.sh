#!/bin/sh
set -e

CONF_DIR="/data/conf"
RELAY_ADDR=${RELAY_ADDR:-"us.tinybear.cc"}
RELAY_PORT=${RELAY_PORT:-21117}

cd "$CONF_DIR"

# On first run, start hbbs briefly to generate the ed25519 key pair, then kill it
if [ ! -f "$CONF_DIR/id_ed25519" ]; then
    echo "[rustdesk] first run, generating ed25519 key pair..."
    /usr/local/bin/hbbs -k _ &
    HBBS_PID=$!
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if [ -f "$CONF_DIR/id_ed25519" ]; then
            break
        fi
        sleep 1
    done
    kill $HBBS_PID 2>/dev/null || true
    wait $HBBS_PID 2>/dev/null || true
    echo "[rustdesk] key pair generated"
fi

if [ -f "$CONF_DIR/id_ed25519.pub" ]; then
    echo "[rustdesk] server public key: $(cat "$CONF_DIR/id_ed25519.pub")"
fi

echo "[rustdesk] starting hbbr relay on 0.0.0.0:${RELAY_PORT}..."
/usr/local/bin/hbbr -k _ -p "$RELAY_PORT" &

sleep 1

echo "[rustdesk] starting hbbs ID server, relay=${RELAY_ADDR}:${RELAY_PORT}..."
exec /usr/local/bin/hbbs -k _ -r "${RELAY_ADDR}:${RELAY_PORT}"
