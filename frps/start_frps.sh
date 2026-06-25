#!/bin/sh

CONF_DIR="/data/conf"
CONF_FILE="$CONF_DIR/frps.toml"
DEFAULT_CONF="/etc/frp/frps.toml"

generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Copy default config if not exists on host
if [ ! -f "$CONF_FILE" ]; then
    echo "[frps] config not found at $CONF_FILE, copying default..."
    mkdir -p "$CONF_DIR"
    cp "$DEFAULT_CONF" "$CONF_FILE"
fi

# Check and generate webServer.password if not set
if ! grep -qE '^\s*webServer\.password\s*=\s*"[^"]+' "$CONF_FILE"; then
    new_pass=$(generate_password)
    if grep -q 'webServer.password' "$CONF_FILE"; then
        sed -i "s|^.*webServer\.password.*|webServer.password = \"$new_pass\"|" "$CONF_FILE"
    else
        echo "webServer.password = \"$new_pass\"" >> "$CONF_FILE"
    fi
    echo "[frps] auto-generated webServer.password: $new_pass"
fi

# Check and generate auth.token if not set
if ! grep -qE '^\s*auth\.token\s*=\s*"[^"]+' "$CONF_FILE"; then
    new_token=$(generate_password)
    if grep -q 'auth.token' "$CONF_FILE"; then
        sed -i "s|^.*auth\.token.*|auth.token = \"$new_token\"|" "$CONF_FILE"
    else
        echo "auth.token = \"$new_token\"" >> "$CONF_FILE"
    fi
    echo "[frps] auto-generated auth.token: $new_token"
fi

echo "[frps] starting with config: $CONF_FILE"
exec /usr/local/bin/frps -c "$CONF_FILE"
