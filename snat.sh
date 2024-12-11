#!/bin/bash -x

### Credit to https://github.com/ppabis/nat-instance for script inspiration

# Wait for second interface to appear
ETH0="ens5"
ETH1="ens6"
while ! ip link show dev $ETH1; do
  sleep 1
done
echo "Devices: public: $ETH1 and private: $ETH0"

### IP forwarding configuration
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/90-nat.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.d/90-nat.conf
echo "net.ipv4.conf.${ETH0}.rp_filter=0" >> /etc/sysctl.d/90-nat.conf
echo "net.ipv4.conf.${ETH1}.rp_filter=0" >> /etc/sysctl.d/90-nat.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.d/90-nat.conf
echo "net.ipv4.conf.${ETH1}.send_redirects=0" >> /etc/sysctl.d/90-nat.conf
sysctl --system

### IPTables configuration
iptables -t nat -A POSTROUTING -o $ETH1 -j MASQUERADE
systemctl enable iptables
service iptables save

# Switch the default route to ETH1
mkdir -p /etc/systemd/network/70-${ETH1}.network.d

cat > /etc/systemd/network/70-${ETH1}.network.d/routepriority.conf << EOF
[Match]
Name=ens6

[DHCPv4]
RouteMetric=500

[IPv6AcceptRA]
RouteMetric=500
EOF
networkctl reload

# Wait for network connection
curl --retry 10 http://www.google.com

# Reestablish connections
systemctl restart amazon-ssm-agent.service
