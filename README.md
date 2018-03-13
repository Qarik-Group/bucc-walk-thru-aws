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

This will create a tiny EC2 VM, with a 64G persistent disk, and a `jumpbox` user whose home folder is placed upon that large persistent disk. If you ever need to enlarge the disk, edit `envs/jumpbox/operators/persistent-homes.yml`, change `disk_size: 65_536` to a larger number, and run `envs/jumpbox/bin/update` again.

