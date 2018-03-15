#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
cd $ROOT

tfoutput="terraform output --state=envs/aws/terraform.tfstate"
cat <<YAML
access_key_id:     $($tfoutput aws.creds.aws_access_key)
secret_access_key: $($tfoutput aws.creds.aws_secret_key)
default_key_name:  $($tfoutput aws.creds.key_name)
private_key:       ../../$($tfoutput aws.creds.key_file)
default_security_groups: [$($tfoutput aws.network.sg.dmz)]
region:            $($tfoutput aws.network.region)

subnet_id:         $($tfoutput aws.network.dmz.subnet)
az:                $($tfoutput aws.network.dmz.az)
internal_cidr:     $($tfoutput aws.network.prefix).0.0/24
internal_gw:       $($tfoutput aws.network.prefix).0.1
internal_ip:       $($tfoutput aws.network.prefix).0.4

external_ip:       $($tfoutput box.jumpbox.public_ip)

spot_bid_price: 10
YAML
