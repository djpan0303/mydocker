#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONTAINER_CTRL="$SCRIPT_DIR/../ctrl_container.sh"

IMAGE_ID="ssclient"
MAX_FAILURES=3
INTERVAL=60
WATCH_MODE=0
STATE_DIR="${STATE_DIR:-/tmp/mydocker_proxy_monitor}"
LOG_FILE=""
LOG_DIR="/var/log"
DIRECT_PROBE_URL="https://www.baidu.com"

usage() {
	cat <<'EOF'
Usage:
	./ssclient/monitor_proxy.sh [options]

Options:
  --image <name>          Container name to monitor, default: ssclient
  --max-failures <n>      Restart after n consecutive failures, default: 3
  --interval <seconds>    Sleep interval in watch mode, default: 60
	--direct-probe-url <u>  Direct-connect probe URL, default: https://www.baidu.com
  --watch                 Run continuously
	--log-file <path>       Optional log filename, normalized into /var/log
  --help                  Show this help

Examples:
	./ssclient/monitor_proxy.sh
	./ssclient/monitor_proxy.sh --watch --interval 30
	./ssclient/monitor_proxy.sh --image ssclient --max-failures 2
	./ssclient/monitor_proxy.sh --direct-probe-url https://www.baidu.com
EOF
}

log() {
	message="$(date '+%F %T') $*"
	if [ -z "$LOG_FILE" ] || [ -t 1 ]; then
		echo "$message"
	fi
	if [ -n "$LOG_FILE" ]; then
		mkdir -p "$(dirname "$LOG_FILE")"
		echo "$message" >>"$LOG_FILE"
	fi
}

generate_log_file() {
	echo "$LOG_DIR/monitory_proxy_$(date '+%F_%H-%M-%S').log"
}

normalize_log_file() {
	if [ -z "$LOG_FILE" ]; then
		generate_log_file
		return 0
	fi

	log_base=$(basename "$LOG_FILE")
	case "$log_base" in
	monitory_proxy_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9].log)
		echo "$LOG_DIR/$log_base"
		;;
	*)
		generate_log_file
		;;
	esac
}

ensure_log_file_writable() {
	if touch "$LOG_FILE" 2>/dev/null; then
		return 0
	fi

	echo "[monitor] no write permission for $LOG_FILE, trying sudo..." >&2
	if command -v sudo >/dev/null 2>&1; then
		sudo touch "$LOG_FILE"
		sudo chown "$(id -u):$(id -g)" "$LOG_FILE"
		sudo chmod 664 "$LOG_FILE"
		return 0
	fi

	echo "[monitor] cannot write $LOG_FILE and sudo is unavailable" >&2
	return 1
}

require_file() {
	file_path=$1
	if [ ! -f "$file_path" ]; then
		echo "required file not found: $file_path" >&2
		exit 1
	fi
}

safe_name() {
	echo "$1" | tr '/ :' '___'
}

state_file_path() {
	mkdir -p "$STATE_DIR"
	echo "$STATE_DIR/$(safe_name "$IMAGE_ID").fail"
}

lock_dir_path() {
	mkdir -p "$STATE_DIR"
	echo "$STATE_DIR/$(safe_name "$IMAGE_ID").lock"
}

read_failures() {
	state_file=$(state_file_path)
	if [ -f "$state_file" ]; then
		cat "$state_file"
	else
		echo 0
	fi
}

write_failures() {
	state_file=$(state_file_path)
	echo "$1" >"$state_file"
}

reset_failures() {
	write_failures 0
}

cleanup_lock() {
	lock_dir=$(lock_dir_path)
	rmdir "$lock_dir" 2>/dev/null || true
}

acquire_lock() {
	lock_dir=$(lock_dir_path)
	if ! mkdir "$lock_dir" 2>/dev/null; then
		log "[monitor] another monitor instance is running, skip"
		exit 0
	fi
	trap cleanup_lock EXIT
}

run_health_check() {
	if ! docker inspect "$IMAGE_ID" >/dev/null 2>&1; then
		log "[monitor] container not running: $IMAGE_ID, monitor exit"
		return 2
	fi

	if ! check_direct_network; then
		log "[monitor] direct network unavailable, skip proxy health check and restart"
		return 0
	fi

	if "$CONTAINER_CTRL" --test; then
		log "[monitor] proxy health check passed"
		reset_failures
		return 0
	fi

	failures=$(read_failures)
	failures=$((failures + 1))
	write_failures "$failures"
	log "[monitor] proxy health check failed, consecutive failures: ${failures}/${MAX_FAILURES}"

	if [ "$failures" -lt "$MAX_FAILURES" ]; then
		return 1
	fi

	log "[monitor] restarting container: $IMAGE_ID"
	if "$CONTAINER_CTRL" --restart "$IMAGE_ID"; then
		log "[monitor] restart completed, rechecking"
		reset_failures
		sleep 8
		if "$CONTAINER_CTRL" --test; then
			log "[monitor] proxy recovered after restart"
			return 0
		fi

		log "[monitor] proxy still unhealthy after restart"
		write_failures "$MAX_FAILURES"
		return 1
	fi

	log "[monitor] restart failed"
	write_failures "$MAX_FAILURES"
	return 1
}

check_direct_network() {
	probe_output=$(curl \
		--silent --show-error --location \
		--connect-timeout 5 --max-time 10 \
		--output /dev/null \
		--write-out "HTTP_CODE=%{http_code} CONNECT=%{time_connect}s TOTAL=%{time_total}s" \
		"$DIRECT_PROBE_URL" 2>&1)
	probe_status=$?

	if [ $probe_status -ne 0 ]; then
		log "[monitor] direct probe failed: ${DIRECT_PROBE_URL} ${probe_output}"
		return 1
	fi

	http_code=$(echo "$probe_output" | sed -n 's/.*HTTP_CODE=\([0-9][0-9][0-9]\).*/\1/p')
	if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
		log "[monitor] direct probe ok: ${DIRECT_PROBE_URL} ${probe_output}"
		return 0
	fi

	log "[monitor] direct probe unexpected status: ${DIRECT_PROBE_URL} ${probe_output}"
	return 1
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--image)
		IMAGE_ID=${2:-}
		shift 2
		;;
	--max-failures)
		MAX_FAILURES=${2:-}
		shift 2
		;;
	--interval)
		INTERVAL=${2:-}
		shift 2
		;;
	--direct-probe-url)
		DIRECT_PROBE_URL=${2:-}
		shift 2
		;;
	--watch)
		WATCH_MODE=1
		shift
		;;
	--log-file)
		LOG_FILE=${2:-}
		shift 2
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		echo "unknown option: $1" >&2
		usage
		exit 1
		;;
	esac
done

require_file "$CONTAINER_CTRL"
acquire_lock

case "$MAX_FAILURES" in
'' | *[!0-9]*)
	echo "--max-failures must be a positive integer" >&2
	exit 1
	;;
esac
case "$INTERVAL" in
'' | *[!0-9]*)
	echo "--interval must be a positive integer" >&2
	exit 1
	;;
esac
if [ "$MAX_FAILURES" -le 0 ] || [ "$INTERVAL" -le 0 ]; then
	echo "numeric options must be greater than zero" >&2
	exit 1
fi
if [ -z "$DIRECT_PROBE_URL" ]; then
	echo "--direct-probe-url cannot be empty" >&2
	exit 1
fi

LOG_FILE=$(normalize_log_file)
ensure_log_file_writable

if [ "$WATCH_MODE" -eq 1 ]; then
	log "[monitor] start watch mode: image=$IMAGE_ID interval=${INTERVAL}s max_failures=$MAX_FAILURES direct_probe_url=$DIRECT_PROBE_URL"
	while true; do
		status=0
		run_health_check || status=$?
		if [ "$status" -ne 0 ]; then
			if [ "$status" -eq 2 ]; then
				log "[monitor] stop watch mode because container is not running"
				exit 0
			fi
		fi
		sleep "$INTERVAL"
	done
else
	status=0
	run_health_check || status=$?
	if [ "$status" -eq 2 ]; then
		exit 0
	fi
	exit "$status"
fi
