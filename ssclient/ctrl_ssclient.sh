#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

PROXY_ADDR="http://127.0.0.1:8118"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor_proxy.sh"
MONITOR_PID_DIR="/tmp/mydocker_proxy_monitor"

function monitor_pid_file() {
	echo "${MONITOR_PID_DIR}/ssclient.monitor.pid"
}

function start_monitor() {
	if [ ! -f "$MONITOR_SCRIPT" ]; then
		echo "[monitor] script not found, skip: $MONITOR_SCRIPT"
		return 0
	fi

	mkdir -p "$MONITOR_PID_DIR"
	pid_file=$(monitor_pid_file)
	if [ -f "$pid_file" ]; then
		old_pid=$(cat "$pid_file" 2>/dev/null || true)
		if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
			echo "[monitor] already running, pid=$old_pid"
			return 0
		fi
		rm -f "$pid_file"
	fi

	echo "[monitor] starting watch process"
	nohup "$MONITOR_SCRIPT" --watch --interval 60 --max-failures 3 \
		--log-file /tmp/proxy-monitor.log >/tmp/proxy-monitor.stdout.log 2>&1 &
	monitor_pid=$!
	echo "$monitor_pid" >"$pid_file"
	echo "[monitor] started, pid=$monitor_pid"
}

function stop_monitor() {
	pid_file=$(monitor_pid_file)
	if [ ! -f "$pid_file" ]; then
		echo "[monitor] pid file not found, skip stop"
		return 0
	fi

	monitor_pid=$(cat "$pid_file" 2>/dev/null || true)
	if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
		echo "[monitor] stopping pid=$monitor_pid"
		kill "$monitor_pid" 2>/dev/null || true
	fi
	rm -f "$pid_file"
}

function prepare_config() {
	host_dir=$1
	if [ ! -f "$host_dir/ssr.json" ]; then
		cp -r "$SCRIPT_DIR/conf"/* "$host_dir"
	fi
}

function probe_proxy() {
	probe_name=$1
	probe_url=$2
	expect_codes=$3

	echo "[proxy] probing ${probe_name}: ${probe_url}"
	probe_output=$(curl --proxy "$PROXY_ADDR" \
		--silent --show-error --location \
		--connect-timeout 5 --max-time 15 \
		--output /dev/null \
		--write-out "HTTP_CODE=%{http_code} CONNECT=%{time_connect}s TOTAL=%{time_total}s" \
		"$probe_url" 2>&1)
	probe_status=$?

	if [ $probe_status -ne 0 ]; then
		echo "[proxy] ${probe_name} failed: ${probe_output}"
		return 1
	fi

	http_code=$(echo "$probe_output" | sed -n 's/.*HTTP_CODE=\([0-9][0-9][0-9]\).*/\1/p')
	if echo "$expect_codes" | tr ',' '\n' | grep -qx "$http_code"; then
		echo "[proxy] ${probe_name} ok: ${probe_output}"
		return 0
	fi

	echo "[proxy] ${probe_name} unexpected status: ${probe_output}"
	return 1
}

function show_proxy_exit_ip() {
	echo "[proxy] querying exit ip..."
	ip_output=$(curl --proxy "$PROXY_ADDR" \
		--silent --show-error \
		--connect-timeout 5 --max-time 15 \
		https://api.ipify.org 2>&1)
	ip_status=$?
	if [ $ip_status -ne 0 ]; then
		echo "[proxy] failed to query exit ip: ${ip_output}"
		return 1
	fi

	echo "[proxy] exit ip: ${ip_output}"
	return 0
}

function test_proxy() {
	echo "[proxy] start health check via ${PROXY_ADDR}"
	pass_count=0

	if probe_proxy "http_204" "http://cp.cloudflare.com/generate_204" "204,200"; then
		pass_count=$((pass_count + 1))
	fi

	if probe_proxy "https_204" "https://www.gstatic.com/generate_204" "204,200"; then
		pass_count=$((pass_count + 1))
	fi

	if show_proxy_exit_ip; then
		pass_count=$((pass_count + 1))
	fi

	echo "[proxy] passed checks: ${pass_count}/3"
	if [ $pass_count -lt 2 ]; then
		echo "[proxy] health check failed, upstream proxy may be unavailable"
		return 1
	fi

	echo "[proxy] health check passed"
}

function post_start() {
	echo "where am i?waiting for ssclient bring up"
	sleep 5
	curl --proxy "$PROXY_ADDR" cip.cc
	start_monitor
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--prepare-config)
		prepare_config "$2"
		exit 0
		;;
	--post-start)
		post_start
		exit 0
		;;
	--start-monitor)
		start_monitor
		exit 0
		;;
	--stop-monitor)
		stop_monitor
		exit 0
		;;
	--test)
		test_proxy
		exit 0
		;;
	esac
	shift
done

echo "Usage: $0 [--prepare-config <host_dir>|--post-start|--start-monitor|--stop-monitor|--test]"
exit 1
