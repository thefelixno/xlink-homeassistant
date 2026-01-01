#!/bin/sh
set -euxo pipefail

echo $CLIENT_PRIVKEY > /etc/wireguard/link0.key

ip link add link0 type wireguard

wg set link0 private-key /etc/wireguard/link0.key
wg set link0 listen-port $GATEWAY_PORT
ip addr add 10.0.0.2/24 dev link0
ip link set link0 up
ip link set link0 mtu $LINK_MTU

wg set link0 peer $GATEWAY_PUBKEY allowed-ips 10.0.0.1/32 persistent-keepalive 5 endpoint "$GATEWAY_HOST:$GATEWAY_PORT"

echo "Using socat to forward traffic to app."
socat TCP4-LISTEN:8080,fork,reuseaddr TCP4:$EXPOSE,reuseaddr