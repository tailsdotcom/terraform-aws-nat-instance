#!/bin/bash -x

region="$(ec2-metadata --quiet -R)"
ens6_addr="$(ip -f inet -o addr show dev ens6 | cut -d' ' -f 7 | cut -d/ -f 1)"

function get_instance_private_ip_by_name() {
  local name="$1"
  aws ec2 describe-instances \
    --region "$region" \
    --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running" |
    jq -r .Reservations[0].Instances[0].PrivateIpAddress
}

function run_iptables() {
  local action="$1"
  iptables -t nat "$action" PREROUTING 1 -m tcp -p tcp \
    --dst "$ens6_addr" --dport 80 \
    -j DNAT --to-destination "$(get_instance_private_ip_by_name ${ec2_name}):80"
}

run_iptables -I
while true; do
  sleep 30
  run_iptables -R
done
