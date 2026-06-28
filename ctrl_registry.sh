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

	# Extract hostname from REPO_REGISTRY (e.g. us.tinybear.cc:5000 -> us.tinybear.cc)
	REGISTRY_HOST=$(echo "$REPO_REGISTRY" | cut -d ':' -f 1)
	# CORS origin must be a specific origin (not *) when credentials are sent
	CORS_ORIGIN="http://${REGISTRY_HOST}:8080"

	# Build registry args with CORS support
	REGISTRY_ARGS="-e REGISTRY_STORAGE_DELETE_ENABLED=true -v $REPO_DIR:/var/lib/registry"
	REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin=['$CORS_ORIGIN']"
	REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods=['GET,HEAD,OPTIONS,DELETE']"
	REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers=['Authorization,Accept,Cache-Control']"
	REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Credentials=['true']"
	REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers=['Docker-Content-Digest']"

	# Add auth if credentials are set
	if [ -n "$REPO_USER" ] && [ -n "$REPO_PASS" ]; then
		AUTH_DIR="$HOME/registry-auth"
		mkdir -p "$AUTH_DIR"
		if ! command -v htpasswd &>/dev/null; then
			sudo apt-get update && sudo apt-get install -y apache2-utils
		fi
		htpasswd -Bbc "$AUTH_DIR/htpasswd" "$REPO_USER" "$REPO_PASS"
		REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH=htpasswd"
		REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH_HTPASSWD_REALM='Registry Realm'"
		REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd"
		REGISTRY_ARGS="$REGISTRY_ARGS -v $AUTH_DIR:/auth"
	fi

	docker network create registry-net 2>/dev/null || true

	docker run -d --restart=always \
		--name=registry-srv -p 5000:5000 \
		--network registry-net \
		$REGISTRY_ARGS \
		registry

	# Modern registry UI (joxit/docker-registry-ui) in proxy mode
	# Nginx in the container proxies /v2/ requests to registry-srv, avoiding CORS entirely

	WEB_ARGS="--network registry-net"
	WEB_ARGS="$WEB_ARGS -e REGISTRY_URL="
	WEB_ARGS="$WEB_ARGS -e SINGLE_REGISTRY=true"
	WEB_ARGS="$WEB_ARGS -e DELETE_IMAGES=true"
	WEB_ARGS="$WEB_ARGS -e NGINX_PROXY_PASS_URL=http://registry-srv:5000"
	if [ -n "$REPO_USER" ] && [ -n "$REPO_PASS" ]; then
		AUTH_BASE64=$(echo -n "${REPO_USER}:${REPO_PASS}" | base64)
		WEB_ARGS="$WEB_ARGS -e NGINX_PROXY_HEADER_Authorization='Basic ${AUTH_BASE64}'"
	fi

	docker run -d --restart=always \
		--name registry-web \
		-p 8080:80 \
		$WEB_ARGS \
		joxit/docker-registry-ui:latest
}"

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
