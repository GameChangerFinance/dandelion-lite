#!/bin/bash

# Function to calculate EUI-64 from a MAC address
mac_to_eui64() {
    mac="$1"
    IFS=':' read -r -a parts <<< "$mac"

    # Flip the 7th bit of the first byte
    first_byte=$((0x${parts[0]} ^ 0x02))
    parts[0]=$(printf "%02x" $first_byte)

    # Insert ff:fe in the middle
    eui64="${parts[0]}${parts[1]}:${parts[2]}ff:fe${parts[3]}:${parts[4]}${parts[5]}"
    echo "$eui64"
}

# Get public IPv4 address
public_ipv4=$(dig @resolver4.opendns.com myip.opendns.com +short -4)
echo -e "Public IPv4:\t\t$public_ipv4\n"

# Get all interfaces that are UP (excluding loopback and virtual)
interfaces=$(ip -br link | awk '$2 == "UP" && $1 != "lo" { print $1 }')

for iface in $interfaces; do
    # Skip known virtual interfaces
    if [[ "$iface" == docker* || "$iface" == veth* || "$iface" == br-* || "$iface" == virbr* ]]; then
        continue
    fi

    echo -e "Interface:\t\t$iface"

    # MAC address
    mac_addr=$(cat /sys/class/net/$iface/address)
    echo -e "\tMAC:\t\t$mac_addr"

    # Calculate EUI-64
    eui64=$(mac_to_eui64 "$mac_addr")
    echo -e "\tEUI-64:\t\t$eui64"

    # IPv4 address
    ipv4_addr=$(ip -4 addr show dev "$iface" | grep -oP 'inet \K[^/]+')
    if [ -n "$ipv4_addr" ]; then
        echo -e "\tIPv4:\t\t$ipv4_addr"
    fi

    # Global IPv6 addresses
    ipv6_addrs=$(ip -6 addr show dev "$iface" scope global | grep -oP 'inet6 \K[^/]+')
    i=1
    for addr in $ipv6_addrs; do
        if [[ "$addr" =~ ${eui64}$ ]]; then
            echo -e "\tIPv6_EUI64:\t$addr"
        else
            echo -e "\tIPv6_$i:\t\t$addr"
            ((i++))
        fi
    done

    echo
done
