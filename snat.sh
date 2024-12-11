#!/bin/bash -x

# wait for ens6
while ! ip link show dev ens6; do
  sleep 1
done

sysctl -q -w net.ipv4.conf.all.rp_filter=0
sysctl -q -w net.ipv4.conf.ens5.rp_filter=0
sysctl -q -w net.ipv4.conf.ens6.rp_filter=0
sysctl -q -w net.ipv4.conf.default.rp_filter=0


# enable IP forwarding and NAT
sysctl -q -w net.ipv4.ip_forward=1
sysctl -q -w net.ipv4.conf.ens6.send_redirects=0

iptables -t nat -A POSTROUTING -o ens6 -j MASQUERADE

# switch the default route to ens6
ip route del default dev ens5

# wait for network connection
curl --retry 10 http://www.google.com

# reestablish connections
systemctl restart amazon-ssm-agent.service
