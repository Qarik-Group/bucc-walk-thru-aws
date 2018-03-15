#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
cd $ROOT

tfoutput="terraform output --state=envs/aws/terraform.tfstate"
cat <<YAML
az:            $($tfoutput aws.network.private.az)
subnet_id:     $($tfoutput aws.network.private.subnet)
internal_cidr: $($tfoutput aws.network.prefix).1.0/24
internal_gw:   $($tfoutput aws.network.prefix).1.1

dmz_subnet_id:           $($tfoutput aws.network.dmz.subnet)
cf_services_subnet_id:   $($tfoutput aws.network.cf-services.subnet)
YAML
