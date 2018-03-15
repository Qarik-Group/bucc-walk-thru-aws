#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
cd $ROOT

private_key_prefix=${private_key_prefix:-../../../..}
tfoutput="terraform output --state=envs/aws/terraform.tfstate"
cat <<YAML
access_key_id:     $($tfoutput aws.creds.aws_access_key)
secret_access_key: $($tfoutput aws.creds.aws_secret_key)
default_key_name:  $($tfoutput aws.creds.key_name)
private_key:       ${private_key_prefix}/$($tfoutput aws.creds.key_file)
default_security_groups: [$($tfoutput aws.network.sg.dmz), $($tfoutput aws.network.sg.wide-open)]
region:            $($tfoutput aws.network.region)

subnet_id:         $($tfoutput aws.network.private.subnet)
az:                $($tfoutput aws.network.private.az)
internal_cidr:     $($tfoutput aws.network.prefix).1.0/24
internal_gw:       $($tfoutput aws.network.prefix).1.1
internal_ip:       $($tfoutput aws.network.prefix).1.4

director_name: bucc-walk-thru

instance_type: m4.2xlarge
ephemeral_disk_size: 80_000
spot_bid_price: 1
YAML