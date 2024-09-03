#!/bin/bash

# GLOBAL VARIABLES
PID_FILE="/run/terraform-shard-manager.pid"
CURRENT_SCRIPT_LOGS="/tmp/bootstrap-cluster.log"

exec >$CURRENT_SCRIPT_LOGS 2>&1

function cleanup() {
	if [ -f "$PID_FILE" ]; then
		rm -f "$PID_FILE"
	fi
}

function create_pid_file()  {
	local max_attempts=5

	for ((i=$max_attempts; i>0;i--)); do
		if [ -f "$PID_FILE" ]; then
			echo "Script is already running with PID $(cat "$PID_FILE"). Waiting process to end..."
			sleep 1m
			continue
		fi

		echo $$ > "$PID_FILE"
		trap cleanup EXIT
		return 0
	done

	echo "Exiting due to waiting too long for the process to finish."
	exit 1
}

function get_replica_shard() {
    local public_ips=("$@")
    local members="[]"
    local config='{"_id": "shard_repl", "members": []}'

    for ((i=0; i<${#public_ips[@]}; i++)) {
        local member="{\"_id\": $i, \"host\": \"${public_ips[i]}:28041\"}"
        members=$(jq --argjson newMember "$member" '. + [$newMember]' <<<"$members")
    }

    config=$(jq --argjson members "$members" '.members += $members' <<<"$config")

    echo "$config"
}

function get_replica_shard_script() {
    local rsconf
    local replica_set_config
    rsconf=$(get_replica_shard "$@")
    replica_set_config=$(cat <<EOF
rsconf = ${rsconf};
rs.initiate(rsconf);
rs.status();
EOF
)

    echo -e "$replica_set_config"
}

function cluster_initialized() {
    if [[ "$(mongosh --port 28041 --eval 'rs.status().ok')" == "1" ]]; then
        return 0
    fi

    return 1
}

function setup() {
    local rsconf

    if cluster_initialized; then
        echo "The cluster has already been initialized. Skipping initialization..."
        exit 0
    fi

    rsconf=$(get_replica_shard_script "$@")
    sleep 2m # TODO: ensure the other instances is ready to join the cluster

    mongosh --port 28041 --eval "$rsconf" 
}

create_pid_file
setup "$@"
