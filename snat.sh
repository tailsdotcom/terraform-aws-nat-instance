#!/bin/bash

### Credit to https://github.com/ppabis/nat-instance for mosst of this script

### IP forwarding configuration
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/90-nat.conf
sysctl --system

### Get eth1 and eth0 real names
ITERATIONS=10
ETH1=""
# Wait for "eth1" to be detected by kernel and get its real name
while [ -z $ETH1 ] && [ $ITERATIONS -gt 0 ]; do
  sleep 3
  # device-number-1 is secondary interface as specified by device_index = 1
  ETH1=$(ip -4 addr show device-number-1 | grep -oP 'ens[0-9]+' | head -n1)
  ITERATIONS=$((ITERATIONS-1))
done
# Select public interface that is not "eth1"
ETH0=$(ip -4 addr show device-number-0 | grep -oP 'ens[0-9]+' | head -n1)
echo "Devices: public: $ETH0 and private: $ETH1"

### IPTables configuration
iptables -t nat -A POSTROUTING -o $ETH0 -j MASQUERADE
iptables -A FORWARD -i $ETH0 -o $ETH1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $ETH1 -o $ETH0 -j ACCEPT
systemctl enable iptables
service iptables save

### Routing configuration
# Add traffic coming at eth1 that is not from the same submet to be routed through
# itself so the packtes are not lost
mkdir -p /etc/systemd/network/70-$ETH1.network.d
%{for cidr in setsubtract(private_subnets, [primary_subnet])~}
echo "[Route]" >> /etc/systemd/network/70-$ETH1.network.d/routes.conf
echo "Destination=${cidr}" >> /etc/systemd/network/70-$ETH1.network.d/routes.conf
echo "Gateway=${cidrhost(primary_subnet, 1)}" >> /etc/systemd/network/70-$ETH1.network.d/routes.conf
echo "GatewayOnlink=yes" >> /etc/systemd/network/70-$ETH1.network.d/routes.conf
echo "" >> /etc/systemd/network/70-$ETH1.network.d/routes.conf
%{~endfor}
networkctl reload

# Wait for network connection
curl --retry 10 http://www.google.com

# Reestablish connections
systemctl restart amazon-ssm-agent.service
