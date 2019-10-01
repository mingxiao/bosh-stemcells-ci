#!/usr/bin/env bash

set -e

until lpass status;do
  LPASS_DISABLE_PINENTRY=1 lpass ls a
  sleep 1
done

until fly -t pcf status;do
  fly -t pcf login
  sleep 1
done

pipeline_config=$(mktemp)
ytt -f "$(dirname $0)" > $pipeline_config
# ytt -f "$(dirname $0)"

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -l <(lpass show --notes "concourse:production pipeline:os-images" ) \
  -l <(lpass show --notes "concourse:production pipeline:bosh:stemcells" ) \
  -l <(lpass show --notes "bats-concourse-pool:vsphere secrets" ) \
  -l <(lpass show --notes "stemcell-reminder-bot") \
  -c "$pipeline_config"
