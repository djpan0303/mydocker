#!/bin/bash
set -e
source $(dirname $0)/config.sh

SSCLIENT_CTRL="$(dirname $0)/ssclient/ctrl_ssclient.sh"

function ensure_ssclient_ctrl() {
	if [ ! -x "$SSCLIENT_CTRL" ]; then
		echo "ssclient control script not executable: $SSCLIENT_CTRL"
		exit 1
	fi
}

function stop() {
	image_id=$1
	check_param_empty $image_id "image_id"
	if [ "$image_id" = "ssclient" ]; then
		ensure_ssclient_ctrl
		"$SSCLIENT_CTRL" --stop-monitor
	fi
	if docker inspect "$image_id" &>/dev/null; then
		echo "stop container $image_id"
		docker rm -f $image_id
	else
		echo "container $image_id not running, skip stop"
	fi
}

function start() {
	image_id=$1
	opt_pull=$2
	check_param_empty $image_id "image_id"
	stop $image_id

	image_tag=$image_id
	script_dir=$(dirname $0)
	if [ -f "$script_dir/$image_id/$TAG_ID_FILE" ]; then
		tag_id=$(cat "$script_dir/$image_id/$TAG_ID_FILE")
		image_tag="$image_id:$tag_id"
	fi

	# if specify --pull, pull the image from registry
	if [ "$opt_pull" == "--pull" ]; then
		echo "pull image $image_tag from registry"
		check_registry_login
		docker pull "$REPO_REGISTRY/$image_tag"
	fi

	# place your config file under /data/conf
	host_dir=$CONFIG_DIR
	os_type=$(uname)
	if [ $os_type == "Darwin" ]; then
		host_dir=$HOME/$CONFIG_DIR
	fi

	# ensure config directory exists
	if [ ! -d $host_dir ]; then
		sudo mkdir -p $host_dir && sudo chmod 777 $host_dir
	fi

	echo "start new container..."
	if [ "$image_id" == "frpc" ]; then
		# copy frpc config if not exist
		if [ ! -f $host_dir/frpc.toml ]; then
			cp $(dirname $0)/frpc/conf/frpc.toml $host_dir/frpc.toml
		fi

		docker run -dt --restart=always \
			--network host \
			--name $image_id \
			-v $host_dir/frpc.toml:$CONFIG_DIR/frpc.toml \
			-v $host_dir/frpc.toml:/etc/frp/frpc.toml \
			$REPO_REGISTRY/$image_tag
	elif [ "$image_id" == "frps" ]; then
		# copy frps config if not exist
		if [ ! -f $host_dir/frps.toml ]; then
			cp $(dirname $0)/frps/frps.toml $host_dir/frps.toml
		fi

		docker run -dt --restart=always \
			--network host \
			--name $image_id \
			-v $host_dir/frps.toml:$CONFIG_DIR/frps.toml \
			$REPO_REGISTRY/$image_tag
	elif [ "$image_id" == "ssserver" ]; then
		# copy ssserver config if not exist
		if [ ! -f $host_dir/ssserver.json ]; then
			cp $(dirname $0)/ssserver/conf/config.json $host_dir/ssserver.json
		fi

		docker run -dt --restart=always \
			-p 9544:9544 \
			--name $image_id \
			-v $host_dir/ssserver.json:$CONFIG_DIR/config.json \
			$REPO_REGISTRY/$image_tag
	elif [ "$image_id" == "rustdesk" ]; then
		docker run -dt --restart=always \
			--network host \
			--name $image_id \
			-e RELAY_ADDR=us.tinybear.cc \
			-v $host_dir:$CONFIG_DIR \
			$REPO_REGISTRY/$image_tag
	else
		ensure_ssclient_ctrl
		# copy ssclient config if not exist
		"$SSCLIENT_CTRL" --prepare-config "$host_dir"

		docker run -dt --restart=always \
			-p 8118:8118 \
			--name $image_id \
			-v $host_dir/ssr.json:$CONFIG_DIR/ssr.json \
			-v $host_dir/privoxy_config:/etc/privoxy/config \
			$REPO_REGISTRY/$image_tag

		docker ps -a --no-trunc | grep "$image_id"

		# validate
		if [ "$image_id" = "ssclient" ]; then
			"$SSCLIENT_CTRL" --post-start
		fi
	fi

}

function login() {
	image_id=$1
	USER="root"
	check_param_empty $image_id "image_id"
	docker exec -it -u ${USER} $image_id /bin/bash
}

function test_ssclient() {
	ensure_ssclient_ctrl
	"$SSCLIENT_CTRL" --test
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	# start or restart container
	--start | --restart)
		stop $2
		start $2 $3
		exit 0
		;;
	--login)
		login $2
		exit 0
		;;
	--stop)
		stop $2
		exit 0
		;;
	--test)
		test_ssclient
		exit 0
		;;
	esac
	shift
done
