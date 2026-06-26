#!/bin/sh
set -eu

export PYTHONHOME=/usr

APP_TYPE="${1:-ssr}"

CONF_DIR="/data/conf"
PRIVOXY_CONF="${CONF_DIR}/privoxy_config"
SSR_CONF="${CONF_DIR}/ssr.json"
DEFAULT_PRIVOXY_CONF="/etc/privoxy/config"

# Setup privoxy config
if [ -f "$PRIVOXY_CONF" ]; then
    echo "[ssclient] using custom privoxy config: $PRIVOXY_CONF"
    mkdir -p /etc/privoxy
    cp "$PRIVOXY_CONF" "$DEFAULT_PRIVOXY_CONF"
else
    # Apply forward-socks5t rule and listen-address
    if [ -f "$DEFAULT_PRIVOXY_CONF" ]; then
        if ! grep -q 'forward-socks5t' "$DEFAULT_PRIVOXY_CONF"; then
            echo "forward-socks5t   /               127.0.0.1:1080 ." >> "$DEFAULT_PRIVOXY_CONF"
        fi
        sed -i "s/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:8118/g" "$DEFAULT_PRIVOXY_CONF"
    fi
fi

# Start privoxy
echo "[ssclient] starting privoxy..."
privoxy --no-daemon "$DEFAULT_PRIVOXY_CONF" &
PRIVOXY_PID=$!

# Start shadowsocks local client
if [ -f "$SSR_CONF" ]; then
    echo "[ssclient] starting shadowsocksr with config: $SSR_CONF"
    exec python2.7 /data/app/ssr/shadowsocks/local.py -c "$SSR_CONF"
else
    echo "[ssclient] SSR config not found at $SSR_CONF, waiting for privoxy only"
    wait $PRIVOXY_PID
fi
