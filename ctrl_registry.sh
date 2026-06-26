#!/bin/bash
set -e
# set -x

source ./config.sh

# https://gist.github.com/jaytaylor/86d5efaddda926a25fa68c263830dac1
function remove() {
	image_tag=$1
	check_param_empty $image_tag "image_tag"
	check_registry_creds

	echo "remove $image_tag from registry"

	image_id=$(echo ${image_tag} | cut -d ':' -f 1)
	tag_id=$(echo ${image_tag} | cut -d ':' -f 2)
	curl -v -sSL -u ${REPO_USER}:${REPO_PASS} -X DELETE "http://${REPO_REGISTRY}/v2/${image_id}/manifests/$(
		curl -sSL -u ${REPO_USER}:${REPO_PASS} -I \
			-H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
			"http://${REPO_REGISTRY}/v2/${image_id}/manifests/${tag_id}" |
			awk '$1 == "Docker-Content-Digest:" { print $2 }' |
			tr -d $'\r'
	)"
}

function list() {
	image_id=$1
	check_param_empty $image_id "image_id"
	check_registry_creds
	echo "list image $image_id tag list"
	curl -sSL -u ${REPO_USER}:${REPO_PASS} "http://${REPO_REGISTRY}/v2/$image_id/tags/list" | jq
}

function stop_server() {
	docker rm -f registry-srv
	docker rm -f registry-web
}

function start_server() {
	mkdir -p $REPO_DIR

	stop_server

	docker run -d --restart=always \
		--name=registry-srv -p 5000:5000 \
		-e REGISTRY_STORAGE_DELETE_ENABLED=true -v $REPO_DIR:/var/lib/registry \
		registry

	# -e REGISTRY_READONLY=false\
	docker run -dt --restart=always \
		--name registry-web \
		-p 8080:8080 \
		--link registry-srv -e REGISTRY_URL=http://registry-srv:5000/v2 \
		-e REGISTRY_NAME=localhost:5000 hyper/docker-registry-web
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--remove)
		remove $2
		exit 0
		;;
	--list)
		list $2
		exit 0
		;;
	--start_server)
		start_server
		exit 0
		;;
	--stop_server)
		stop_server
		exit 0
		;;
	esac
	shift
done
