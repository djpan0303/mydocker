REPO_REGISTRY=us.tinybear.cc:5000
CONFIG_DIR="/data/conf"
TAG_ID_FILE="tag_id.txt"
REPO_DIR=$HOME/registry
REPO_USER=""
REPO_PASS=""

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

function check_registry_login() {
    # Skip if already logged in via docker
    if [ -f ~/.docker/config.json ] && grep -q "\"$REPO_REGISTRY\"" ~/.docker/config.json 2>/dev/null; then
        return 0
    fi

    echo "[registry] Not logged in to $REPO_REGISTRY"
    if [ -z "$REPO_USER" ]; then
        echo -n "Username: "
        read REPO_USER
    fi
    if [ -z "$REPO_PASS" ]; then
        echo -n "Password: "
        read -s REPO_PASS
        echo ""
    fi

    if [ -z "$REPO_USER" ] || [ -z "$REPO_PASS" ]; then
        echo "Username or password is empty, abort."
        exit 1
    fi

    echo "$REPO_PASS" | docker login "$REPO_REGISTRY" -u "$REPO_USER" --password-stdin
    if [ $? -ne 0 ]; then
        # Check if registry is HTTP-only and needs insecure-registries config
        if curl -sSL -o /dev/null -w "%{http_code}" "http://$REPO_REGISTRY/v2/" 2>/dev/null | grep -q '^\(200\|401\)$'; then
            echo ""
            echo "[registry] $REPO_REGISTRY is an HTTP registry but not in Docker's insecure-registries."
            echo "[registry] Run the following to fix:"
            echo "  sudo jq '.[\"insecure-registries\"] += [\"$REPO_REGISTRY\"]' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.tmp && sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json"
            echo "  sudo systemctl restart docker"
            echo "  Then re-run your command."
        fi
        echo "Login to $REPO_REGISTRY failed!"
        exit 1
    fi
}

function check_registry_creds() {
    if [ -z "$REPO_USER" ]; then
        echo -n "[registry] Username for $REPO_REGISTRY: "
        read REPO_USER
    fi
    if [ -z "$REPO_PASS" ]; then
        echo -n "[registry] Password: "
        read -s REPO_PASS
        echo ""
    fi
    if [ -z "$REPO_USER" ] || [ -z "$REPO_PASS" ]; then
        echo "Username or password is empty, abort."
        exit 1
    fi
}

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
