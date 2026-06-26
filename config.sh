REPO_REGISTRY=us.tinybear.cc:5000
CONFIG_DIR="/data/conf"
TAG_ID_FILE="tag_id.txt"
REPO_DIR=$HOME/registry

function check_param_empty() {
	param_value=$1
	param_name=$2
	if [ -z "$param_value" ]; then
		echo "$param_name is empty"
		exit 1
	fi
}

# install jq
if ! command -v jq &>/dev/null; then
	echo "jq could not be found, installing..."
	if command -v apt-get &>/dev/null; then
		sudo apt-get update && sudo apt-get install -y jq
	elif command -v yum &>/dev/null; then
		sudo yum install -y jq
	else
		echo "Neither apt-get nor yum found. Please install jq manually."
		exit 1
	fi
fi

# check if /data/conf/privoxy_config exists, if not, copy it from ssclient/conf/privoxy_config
if [ ! -f "$CONFIG_DIR/privoxy_config" ]; then
	echo "privoxy_config not found in $CONFIG_DIR, copying from ssclient/conf/privoxy_config..."
	if [ ! -f "$(dirname $0)/ssclient/conf/privoxy_config" ]; then
		echo "Source privoxy_config not found in ssclient/conf/privoxy_config. Please make sure it exists."
		exit 1
	fi
	sudo mkdir -p $CONFIG_DIR
	sudo cp "$(dirname $0)/ssclient/conf/privoxy_config" $CONFIG_DIR/
fi
