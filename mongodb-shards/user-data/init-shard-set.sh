#!/bin/bash

exec >/tmp/init-shard-set.log 2>&1

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

function setup() {
    local rsconf

    rsconf=$(get_replica_shard_script "$@")

    mongosh --port 28041 --eval "$rsconf" 
}

setup "$@"