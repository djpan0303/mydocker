set -e
sudo apt update
apt install python2 -y
apt install python3 -y

setup_script_dir=$(dirname $0)
cd $setup_script_dir
./shadowsocks-all.sh

ln -s /usr/bin/python2 /usr/bin/python
systemctl enable shadowsocks-r
systemctl start shadowsocks-r