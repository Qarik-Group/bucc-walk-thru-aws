#!/bin/bash

# The base manifests/redis.yml assumes that your `bosh cloud-config` contains
# "vm_type" and "networks" named "default". Its quite possible you don't have this.
# This script will select the first "vm_types" and first "networks" to use in
# your deployment. It will print to stderr the choices it made.
#
# Usage:
#   bosh deploy manifests/redis.yml -o <(./manifests/operators/pick-from-cloud-config.sh)

: ${BOSH_ENVIRONMENT:?required}

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
cd $ROOT

vm_types="default minimal small large sharedcpu small-highmem"
for vm_type in $vm_types; do
cat <<YAML
- type: replace
  path: /vm_types/name=${vm_type}/cloud_properties/spot_bid_price?
  value: 1.0

YAML
done
