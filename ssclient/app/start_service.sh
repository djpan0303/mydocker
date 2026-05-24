#!/bin/bash
set -x
APP_TYPE=$1

systemctl start privoxy

python2.7 /data/app/ssr/shadowsocks/local.py -c /data/conf/ssr.json >/dev/null 2>&1

tail