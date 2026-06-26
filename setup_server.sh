#!/bin/bash

set -euo pipefail
set -x
# install necessary tools
sudo apt update
sudo apt install -y python2 python3 curl wget git
# install docker
sudo apt install -y docker.io

# install shadowsocks-r server
cd ssserver
sudo ./setup.sh

# bring up frps container
