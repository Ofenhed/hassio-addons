#!/usr/bin/env bashio

set -e

private_key=$(bashio::config 'wg_private_key')

if wg_interface_name=$(bashio::config 'wg_interface_name' wg0)

fwmark=$(wg show "$wg_interface_name" fwmark)

while [ $((0+fwmark)) -eq 0 ]; do
    fwmark="$RANDOM"
    wg set "$wg_interface_name" fwmark "$fwmark"
done

route_table_id=$(bashio::app.option 'route_table_id' 100)
route_table_id=$((0+route_table_id))

log_status_interval=$(bashio::app.option 'log_status_interval' 0)

block_non_wireguard=$(bashio::app.option 'block_non_wireguard' false)

function teardown_wg() {
    set +e
    ip link delete "$wg_interface_name"
    ip rule del not fwmark "$fwmark" table "$route_table_id"
    ip route flush table "$route_table_id"
}

trap teardown_wg EXIT

ip link add "$wg_interface_name" type wireguard

conf_file=$(mktemp)

bashio::app.option 'wg_config' > "$conf_file"

wg setconf "$wg_interface_name" "$conf_file"
rm -f "$conf_file"

ip rule add not fwmark "$fwmark" table "$route_table_id"
if [ $block_non_wireguard = "true" ]; then
    ip route add table "$route_table_id" to blackhole default priority 100
fi

wg set "$wg_interface_name" private-key <(cat <<<"$private_key")
unset private_key

ip link set "$wg_interface_name" up
ip route add table "$route_table_id" to default dev "$wg_interface_name" priority 1

wg show
if [ "$log_status_interval" -eq 0 ]; then
    sleep inf
fi

while wg show; do
    sleep -- "$log_status_interval"
done
