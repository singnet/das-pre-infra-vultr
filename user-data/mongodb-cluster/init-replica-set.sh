#!/bin/bash

#get all paramerters
#shift nos argumentos
#

function get_replica_config() {
    local public_ips=("$@")
    local members="[]"
    local config='{"_id": "config_repl", "members": []}'

    for ((i=0; i<${#public_ips[@]}; i++)) {
        local member="{\"_id\": \"$i\", \"host\": \"${public_ips[i]}\"}"
        members=$(jq --argjson newMember "$member" '. + [$newMember]' <<<"$members")
    }

    config=$(jq --argjson members "$members" '.members += $members' <<<"$config")

    echo "$config"
}

function get_replica_config_script() {
    local rsconf=$(get_replica_config "127.0.0.0" "125.0.0.0")
    local replica_set_config=$(cat <<EOF
rsconf = ${rsconf}
rs.initiate(rsconf)
rs.status()
EOF
)

    echo -e "$replica_set_config"
}

function setup() {
    local rsconf=$(get_replica_config_script)

    docker exec -it configrepl1 mongosh "$rsconf"
}

setup