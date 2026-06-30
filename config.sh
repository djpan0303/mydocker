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

# 检查 REPO_REGISTRY 是否在 Docker 的 insecure-registries 配置中，如果不在，则添加
function check_insecure_registry() {
	if [ ! -f /etc/docker/daemon.json ] || [ ! -s /etc/docker/daemon.json ]; then
		echo "Creating /etc/docker/daemon.json with insecure-registries."
		sudo mkdir -p /etc/docker
		echo "{\"insecure-registries\": [\"$REPO_REGISTRY\"]}" | sudo tee /etc/docker/daemon.json >/dev/null
		sudo systemctl restart docker
	else
		if ! grep -q "\"$REPO_REGISTRY\"" /etc/docker/daemon.json; then
			echo "Adding $REPO_REGISTRY to Docker's insecure-registries."
			if sudo jq -e --arg registry "$REPO_REGISTRY" 'has("insecure-registries") and (."insecure-registries" | type == "array")' /etc/docker/daemon.json >/dev/null 2>&1; then
				sudo jq --arg registry "$REPO_REGISTRY" '."insecure-registries" += [$registry]' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.tmp >/dev/null && sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
			else
				if sudo jq -e --arg registry "$REPO_REGISTRY" '. + {"insecure-registries": [$registry]}' /etc/docker/daemon.json >/dev/null 2>&1; then
					sudo jq --arg registry "$REPO_REGISTRY" '. + {"insecure-registries": [$registry]}' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.tmp >/dev/null && sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
				else
					echo "Warning: /etc/docker/daemon.json is invalid JSON, recreating it."
					echo "{\"insecure-registries\": [\"$REPO_REGISTRY\"]}" | sudo tee /etc/docker/daemon.json >/dev/null
				fi
			fi
			sudo systemctl restart docker
		fi
	fi

	return 0
}

function check_registry_login() {

	check_insecure_registry

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
