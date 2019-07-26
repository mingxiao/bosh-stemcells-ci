#!/usr/bin/env bash

set -euo pipefail

until lpass status;do
  LPASS_DISABLE_PINENTRY=1 lpass ls a
done

until fly -t production status;do
  fly -t production login
done

dir=$(dirname $0)

pipeline_config=$(mktemp)
bosh interpolate \
  -o <( bosh int -v group=master -v branch=master -v initial_version=0.0.0  -v bump_version=major -v bosh_agent_version='"*"' "$dir/pipeline-base-ops.yml" ) \
  -o <( bosh int "$dir/pipeline-master-ops.yml" ) \
\
  -o <( bosh int -v group=97.x  -v branch=ubuntu-xenial/97.x  -v initial_version=97.0.0  -v bump_version=minor -v bosh_agent_version='"2.117.*"' "$dir/pipeline-base-ops.yml" ) \
  -o <( bosh int -v group=170.x -v branch=ubuntu-xenial/170.x -v initial_version=170.0.0 -v bump_version=minor -v bosh_agent_version='"2.160.*"' "$dir/pipeline-base-ops.yml" ) \
  -o <( bosh int -v group=250.x -v branch=ubuntu-xenial/250.x -v initial_version=250.0.0 -v bump_version=minor -v bosh_agent_version='"2.193.*"' "$dir/pipeline-base-ops.yml" ) \
  -o <( bosh int -v group=315.x -v branch=ubuntu-xenial/315.x -v initial_version=315.0.0 -v bump_version=minor -v bosh_agent_version='"2.215.*"' "$dir/pipeline-base-ops.yml" ) \
  -o <( bosh int -v group=456.x -v branch=ubuntu-xenial/456.x -v initial_version=456.0.0 -v bump_version=minor -v bosh_agent_version='"2.234.*"' "$dir/pipeline-base-ops.yml" ) \
\
  -o <( bosh int -v group=97.x  -v branch=ubuntu-xenial/97.x  -v initial_version=97.0.0  -v bump_version=minor "$dir/pipeline-branch-ops.yml" ) \
  -o <( bosh int -v group=170.x -v branch=ubuntu-xenial/170.x -v initial_version=170.0.0 -v bump_version=minor "$dir/pipeline-branch-ops.yml" ) \
  -o <( bosh int -v group=250.x -v branch=ubuntu-xenial/250.x -v initial_version=250.0.0 -v bump_version=minor "$dir/pipeline-branch-ops.yml" ) \
  -o <( bosh int -v group=315.x -v branch=ubuntu-xenial/315.x -v initial_version=315.0.0 -v bump_version=minor "$dir/pipeline-branch-ops.yml" ) \
  -o <( bosh int -v group=456.x -v branch=ubuntu-xenial/456.x -v initial_version=456.0.0 -v bump_version=minor "$dir/pipeline-branch-ops.yml" ) \
\
  -o "$dir/../../ops-files/97.x-delete-alicloud-build-ops.yml" \
\
  -l <( lpass show --notes "concourse:production pipeline:os-images" ) \
  -l <( lpass show --notes "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --notes "bats-concourse-pool:vsphere secrets" ) \
  -l <(lpass show --notes "stemcell-reminder-bot") \
  "$dir/pipeline-base.yml" \
  > "$pipeline_config"

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -c "$pipeline_config"
