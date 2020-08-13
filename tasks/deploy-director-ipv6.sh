#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby ruby

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

export BOSH_internal_cidr=$(fromEnvironment '.network1.vCenterCIDR')
export BOSH_internal_gw=$(fromEnvironment '.network1.vCenterGateway')
export BOSH_internal_ip=$(fromEnvironment '.directorIP')
export BOSH_network_name=$(fromEnvironment '.network1.vCenterVLAN')
export BOSH_reserved_range="[$(fromEnvironment '.network1.reservedRange')]"
export BOSH_second_network_name=$BOSH_network_name
export BOSH_second_internal_gw=$(fromEnvironment '.network1IPv6.vCenterGateway')
export BOSH_second_internal_cidr=$(fromEnvironment '.network1IPv6["vCenterCIDR"]')
export BOSH_second_internal_ip=$(fromEnvironment '.network1IPv6["staticIP-1"]')

if [ ! -f director-creds.yml ]; then
  cat > director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
EOF
fi

export bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/vsphere/cpi.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -o bosh-deployment/misc/ipv6/bosh.yml \
  -o bosh-deployment/misc/second-network.yml \
  -o bosh-deployment/vsphere/second-network.yml \
  -o bosh-deployment/misc/ntp.yml \
  -o bosh-deployment/misc/dns.yml \
  -o bosh-stemcells-ci/ops-files/ipv6-director.yml \
  --vars-store director-creds.yml \
  -v director_name=stemcell-smoke-tests-director \
  --vars-env "BOSH" > director.yml

set +e
$bosh_cli create-env director.yml -l director-creds.yml
deployed=$?
cp -r $HOME/.bosh director-state/
cp director.yml director-creds.yml director-state.json director-state/
if [ $deployed -ne 0 ]
then
  exit 1
fi
set -e

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`$bosh_cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$bosh_cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$bosh_cli int director-creds.yml --path /admin_password`

$bosh_cli -n update-cloud-config bosh-deployment/vsphere/cloud-config.yml \
          --ops-file bosh-stemcells-ci/ops-files/reserve-ips.yml \
          --ops-file bosh-stemcells-ci/ops-files/ipv6-cc.yml \
          --vars-env "BOSH"
