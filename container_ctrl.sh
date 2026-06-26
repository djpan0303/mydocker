#!/bin/bash
# set -e
 set -x

source $(dirname $0)/config.sh

function stop() {
    image_id=$1
    check_param_empty $image_id "image_id"
    echo "stop container $image_id"
    docker rm -f $image_id
}

function start() {
    image_id=$1
    check_param_empty $image_id "image_id"
    stop $image_id

    image_tag=$image_id

    # if pull failed
    pull_result=$(timeout 60s docker pull "$REPO_REGISTRY/$image_tag" 2>&1)
    if [ $? -ne 0 ]; then
      echo "pull image $image_tag failed, use local image"
    fi

    # place your config file under /data/conf
    host_dir=$CONFIG_DIR
    os_type=$(uname)
    if [ $os_type == "Darwin" ];then
      host_dir=$HOME/$CONFIG_DIR
    fi

    # ensure config directory exists
    if [ ! -d $host_dir ];then
        sudo mkdir -p $host_dir && sudo chmod 777 $host_dir
    fi

    echo "start new container..."
    if [ "$image_id" == "frpc" ]; then
        # copy frpc config if not exist
        if [ ! -f $host_dir/frpc.toml ];then
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
        if [ ! -f $host_dir/frps.toml ];then
            cp $(dirname $0)/frps/frps.toml $host_dir/frps.toml
        fi

        docker run -dt --restart=always \
            --network host \
            --name $image_id \
            -v $host_dir/frps.toml:$CONFIG_DIR/frps.toml \
            $REPO_REGISTRY/$image_tag
    else
        # copy ssclient config if not exist
        if [ ! -f $host_dir/ssr.json ];then
            cp -r $(dirname $0)/ssclient/conf/* $host_dir
        fi

        docker run -dt --restart=always \
            -p 8118:8118 \
            --name $image_id \
            -v $host_dir/ssr.json:$CONFIG_DIR/ssr.json \
            -v $host_dir/privoxy_config:/etc/privoxy/config \
            $REPO_REGISTRY/$image_tag

        docker ps -a --no-trunc | grep "$image_id"

        # validate
        echo "where am i?waiting for $image_id bring up"
        sleep 5
        curl --proxy "http://127.0.0.1:8118" cip.cc
    fi

}

function login() {
    image_id=$1
    USER="root"
    check_param_empty $image_id "image_id"  
    docker exec -it -u ${USER} $image_id /bin/bash
}

function test() {
  curl --proxy "http://127.0.0.1:8118" cip.cc
}

while [ "$#" -gt 0 ]
do
  case "$1" in
    # start or restart container
    --start | --restart)
      stop $2
      start $2
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
      test $2
      exit 0
      ;;
  esac
  shift
done