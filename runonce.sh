#!/bin/bash -x

# Install missing packages
yum update -y
yum install -y iptables iproute

aws ec2 modify-instance-attribute --no-source-dest-check \
  --region "$(ec2-metadata --quiet -R)" \
  --instance-id "$(ec2-metadata --quiet -i)"

# attach the ENI
aws ec2 attach-network-interface \
  --region "$(ec2-metadata --quiet -R)" \
  --instance-id "$(ec2-metadata --quiet -i)" \
  --device-index 1 \
  --network-interface-id "${eni_id}"

# start SNAT
systemctl enable snat
systemctl start snat
