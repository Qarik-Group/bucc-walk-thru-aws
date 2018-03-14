# Walk thru of BUCC on AWS

This is an example repository. All the state files created from `terraform` and `bosh` are listed in `.gitignore`. After going thru this walk thru, you would copy + paste liberally into your own private Git repository that would allow you to commit your state files.

## Configure and terraform AWS

```plain
cp envs/aws/aws.tfvars{.example,}
```

Populate `envs/aws/aws.tfvars` with your AWS API credentials.

[Create a key pair](https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#KeyPairs:sort=keyName) called `bucc-walk-thru`

The private key will automatically be downloaded by your browser. Copy it into `envs/ssh/bucc-walk-thru.pem`:

```plain
mkdir -p envs/ssh
cp ~/Downloads/bucc-walk-thru.pem envs/ssh/bucc-walk-thru.pem
```

[Allocate an elastic IP](https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#Addresses:sort=PublicIp) and store the IP in `envs/aws/aws.tfvars` at `jumpbox_ip = "<your-ip>"`. This will be used for your jumpbox/bastion host later.

```plain
cd envs/aws
make all
cd -
```

This will create a new VPC, a NAT to allow egress Internet access, and two subnets - a public DMZ for the jumpbox, and a private subnet for BUCC.

## Deploy Jumpbox

This repository already has a submodule to [jumpbox-deployment](https://github.com/cppforlife/jumpbox-deployment), and some wrapper scripts. You are ready to go.

```plain
git submodule update --init
envs/jumpbox/bin/update
```

This will create a tiny EC2 VM, with a 64G persistent disk, and a `jumpbox` user whose home folder is placed upon that large persistent disk. 

Looking inside `envs/jumpbox/bin/update` you can see that it is a wrapper script to use `bosh create-env`. Variables from the terraform output are consumed via the `envs/jumpbox/bin/jumpbox-vars-from-terraform.sh` helper script.

```plain
bosh create-env src/jumpbox-deployment/jumpbox.yml \
  -o src/jumpbox-deployment/aws/cpi.yml \
  -l <(envs/jumpbox/bin/vars-from-terraform.sh) \
  ...
```

If you ever need to enlarge the disk, edit `envs/jumpbox/operators/persistent-homes.yml`, change `disk_size: 65_536` to a larger number, and run `envs/jumpbox/bin/update` again. That's the beauty of `bosh create-env`.

If you get any complaints about subnet availability zones, like `can't use multiple availability zones: subnet in us-east-2c, VM in us-east-2b` then edit `envs/jumpbox/bin/vars-from-terraform.sh` line `az:` for the subnet's suffix letter.

## SSH into Jumpbox

To SSH into jumpbox we will need to store the private key of the `jumpbox` into a file, etc. There is a helper script for this:

```plain
envs/jumpbox/bin/ssh
```

You can see that the `jumpbox` user's home directory is placed on the `/var/vcap/store` persistent disk:

```plain
jumpbox/0:~$ pwd
/var/vcap/store/home/jumpbox
```

## SOCKS5 magic tunnel thru Jumpbox

```plain
envs/jumpbox/bin/socks5-tunnel
```

The output will look like:

```plain
Starting SOCKS5 on port 9999...
export BOSH_ALL_PROXY=socks5://localhost:9999
export CREDHUB_PROXY=socks5://localhost:9999
Unauthorized use is strictly prohibited. All access and activity
is subject to logging and monitoring.
```

## Deploying BUCC


```plain
export bucc_project_root=envs/bucc
source <(src/bucc/bin/bucc env)
bucc up --cpi aws --spot-instance
```

This will create `envs/bucc/vars.yml` stub for you to populate. Fortunately, we have a helper script to get most of it:

```plain
envs/bucc/bin/vars-from-terraform.sh > envs/bucc/vars.yml
```

Now run `bucc up` again:

```plain
bucc up
```

If you get any complaints about subnet availability zones, like `can't use multiple availability zones: subnet in us-east-2c, VM in us-east-2b` then edit `envs/bucc/bin/vars-from-terraform.sh` line `az:` for the subnet's suffix letter, and run `envs/bucc/bin/vars-from-terraform.sh > envs/bucc/vars.yml` again.

BUT... you are about download a few hundred GB of BOSH releases, AND THEN upload them thru the jumpbox to your new BUCC/BOSH VM on AWS. Either it will take a few hours or you can move to the jumpbox and run the commands there.

So let's use the jumpbox. For your convenience, there is a nice wrapper script which uploads this project to your jumpbox, runs `bucc up`, and then downloads the modified state files created by `bucc up`/`bosh create-env` back into this project locally:

```plain
envs/bucc/bin/update-upon-jumpbox
```

Inside the SSH session:

```plain
cd ~/workspace/walk-thru
envs/bucc/bin/update
```

To access your BOSH/CredHub, remember to have your SOCKS5 magic tunnel running in another terminal:

```plain
envs/jumpbox/bin/socks5-tunnel
```

After it has bootstrapped your BUCC/BOSH from either the jumpbox or your local machine:

```plain
export BOSH_ALL_PROXY=socks5://localhost:9999
export CREDHUB_PROXY=socks5://localhost:9999

export bucc_project_root=envs/bucc
source <(envs/bucc/bin/env)

bosh env
```

If you get a connection error like below, your SOCKS5 tunnel is no longer up. Run it again.

```plain
Fetching info:
  Performing request GET 'https://10.10.1.4:25555/info':
    Performing GET request:
      Retry: Get https://10.10.1.4:25555/info: dial tcp [::1]:9999: getsockopt: connection refused
```

Instead, the output should look like:

```plain
Using environment '10.10.1.4' as client 'admin'

Name      bucc-walk-thru
UUID      71fec1e3-d34b-4940-aba8-e53e8c848dd1
Version   264.7.0 (00000000)
CPI       aws_cpi
Features  compiled_package_cache: disabled
          config_server: enabled
          dns: disabled
          snapshots: disabled
User      admin

Succeeded
```

The `envs/bucc/bin/update` script also pre-populated a stemcell:

```plain
$ bosh stemcells
Using environment '10.10.1.4' as client 'admin'

Name                                     Version  OS             CPI  CID
bosh-aws-xen-hvm-ubuntu-trusty-go_agent  3541.9   ubuntu-trusty  -    ami-02f7c167 light
```

## Upgrade Everything

```plain
cd src/bucc
git checkout develop
git pull
cd -

envs/bucc/bin/update-upon-jumpbox
```

## Destroy Everything

To discover all your running deployments

```plain
export bucc_project_root=envs/bucc
source <(envs/bucc/bin/env)

bosh deployments
```

To delete each one:

```plain
bosh delete-deployment -d <name>
```

To destroy your BUCC/BOSH VM and its persistent disk:

```plain
bosh clean-up --all
bucc down
```

To destroy your jumpbox and its persistent disk:

```plain
envs/jumpbox/bin/update delete-env
```

To destroy your AWS VPC, subnets, etc:

```plain
cd envs/aws
make destroy
cd -
```