#!/bin/sh

set -eu

CONF_DIR="/data/conf"
CONF_FILE="$CONF_DIR/frpc.toml"
DEFAULT_CONF="/etc/frp/frpc.toml"

# Copy default config if not exists on host
if [ ! -f "$CONF_FILE" ]; then
    echo "[frpc] config not found at $CONF_FILE, copying default..."
    mkdir -p "$CONF_DIR"
    cp "$DEFAULT_CONF" "$CONF_FILE"
    echo "[frpc] please edit $CONF_FILE to set serverAddr, auth.token, and proxies"
fi

echo "[frpc] starting with config: $CONF_FILE"
exec /usr/local/bin/frpc -c "$CONF_FILE"
