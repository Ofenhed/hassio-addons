#!/usr/bin/with-contenv bashio

set -e

echo "Fetching config"
private_key=$(bashio::config 'wg_private_key')

wg_interface_name=$(bashio::config 'wg_interface_name' wg0)

route_table_id=$(bashio::config 'route_table_id' 100)
route_table_id=$((0+route_table_id))

log_status_interval=$(bashio::config 'log_status_interval' 0)

block_non_wireguard=$(bashio::config 'block_non_wireguard' false)
fwmark=""

function teardown_wg() {
    set +e
    echo "Removing interface"
    ip link delete "$wg_interface_name"
    if [ "$fwmark" != "" ]; then
        echo "Removing routing rule"
        ip rule del not fwmark "$fwmark" table "$route_table_id"
    fi
    echo "Flushing route table"
    ip route flush table "$route_table_id"
}

trap teardown_wg EXIT

echo "Creating interface $wg_interface_name"
ip link "$wg_interface_name" 2>/dev/null || ip link add "$wg_interface_name" type wireguard

wg set "$wg_interface_name" listen-port 51820

echo "Applying config"
wg setconf "$wg_interface_name" <(bashio::config 'wg_config')

echo "Finding fwmark"
fwmark=$(wg show "$wg_interface_name" fwmark)

while [ "$fwmark" == "off" ] || [[ $((0+fwmark)) -eq 0 ]]; do
    fwmark="$RANDOM"
    wg set "$wg_interface_name" fwmark "$fwmark" && break
done

echo "Adding routing rule"
ip rule add not fwmark "$fwmark" table "$route_table_id"
ip rule
if [ $block_non_wireguard = "true" ]; then
    ip route add table "$route_table_id" to blackhole default priority 100
fi

echo "Setting private key"
wg set "$wg_interface_name" private-key <(cat <<<"$private_key")
unset private_key

echo "Bringing $wg_interface_name up"
ip link set "$wg_interface_name" up

echo "Creating routing table $route_table_id"
for peer_ip in $(wg show "$wg_interface_name" allowed-ips | cut -f 2-); do
    ip route add table "$route_table_id" to "$peer_ip" dev "$wg_interface_name" priority 1
done

ip route show table "$route_table_id"

wg show
if [ "$log_status_interval" -eq 0 ]; then
    sleep inf
fi

while wg show; do
    sleep -- "$log_status_interval"
done
