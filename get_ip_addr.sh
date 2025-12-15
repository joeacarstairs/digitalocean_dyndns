#!/bin/sh

ip_version="$1"
if [ -z "${ip_version:-}" ] || ([ "$ip_version" != 4 ] && [ "$ip_version" != 6 ]); then
    echo "Usage: get_ip_addr <4|6>" &>2
    exit 1
fi

if [ $ip_version = 4 ]; then
    curl -4 http://icanhazip.com 2> /dev/null
    exit 0
fi

set -eu
CONN_NAME=${CONN_NAME:-nevis}
conn_device_name="$(nmcli --fields NAME,DEVICE con show | grep ^$CONN_NAME | sed 's/\s\+/ /g' | cut -d' ' -f 2)"
if [ -z "${conn_device_name:-}" ]; then
    echo "Could not find the connection device name for connection: \"$CONN_NAME\"" &>2
    exit 1
fi

device_line_no="$(ip addr | grep -En ^[0-9]+:\ $conn_device_name | cut -d':' -f 1)"
if [ -z "${device_line_no:-}" ]; then
    echo "Could not find device: \"$conn_device_name\" in output of ip addr" &>2
    exit 1
fi

ip_addr_output_for_device="$(ip addr | tail -n +$(($device_line_no + 1)))"

device_no="$(ip addr | tail -n +$device_line_no | head -n 1 | cut -d':' -f 1)"
next_device_no=$(($device_no + 1))
next_device_line_no="$(ip addr | grep -En ^${next_device_no}:\ | cut -d':' -f 1)"
if [ -n "${next_device_line_no:-}" ]; then
    len=$(($next_device_line_no - ($device_line_no + 1)))
    ip_addr_output_for_device="$(echo $ip_addr_output_for_device | head -n $len)"
fi

ipv4_regex="([a-z0-9]{1,3}\.){3}[a-z0-9]{1,3}"
ipv6_regex="([a-z0-9]{1,4}:){7}[a-z0-9]{1,4}"
if [ "$ip_version" = "4" ]; then
    ip_regex="$ipv4_regex"
else
    ip_regex="$ipv6_regex"
fi
ip="$(echo "$ip_addr_output_for_device" | grep "scope global" | grep -oE $ip_regex | head -n 1)"
if [ -z "${ip:-}" ]; then
    echo "Could not find global IP in output of ip addr under device: $conn_device_name ($CONN_NAME)"
    exit 1
fi

echo "$ip"
