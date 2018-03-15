variable "aws_access_key" {} # Your Access Key ID                       (required)
variable "aws_secret_key" {} # Your Secret Access Key                   (required)
output "aws.creds.aws_access_key" {
  value = "${var.aws_access_key}"
}
output "aws.creds.aws_secret_key" {
  value = "${var.aws_secret_key}"
}
variable "aws_vpc_name"   {} # Name of your VPC                         (required)

variable "aws_key_name"   {} # Name of EC2 Keypair                      (required)
output "aws.creds.key_name" {
  value = "${var.aws_key_name}"
}
variable "aws_key_file"   {} # Location of the private EC2 Keypair file (required)
output "aws.creds.key_file" {
  value = "${var.aws_key_file}"
}

variable "aws_region"     { default = "us-west-2" } # AWS Region
output "aws.network.region" {
  value = "${var.aws_region}"
}

variable "network"        { default = "10.4" }      # First 2 octets of your /16
output "aws.network.prefix" {
  value = "${var.network}"
}

variable "aws_az1"        { default = "a" }
variable "aws_az2"        { default = "b" }
variable "aws_az3"        { default = "c" }

variable "jumpbox_ip"     {} # IP to be used for jumpbox/bastion
output "box.jumpbox.public_ip" {
  value = "${var.jumpbox_ip}"
}

#
# VPC NAT AMI
#
# These are the region-specific IDs for the Amazon-suggested
# AMI for running a NAT instance inside of a VPC:
#
#    amzn-ami-vpc-nat-hvm-2017.03.1.20170812-x86_64-ebs
#
# The username to log into the nat box is `ec2-user'

variable "aws_nat_ami" {
  default = {
    ap-northeast-1 = "ami-c4887fa2"
    ap-northeast-2 = "ami-a462bbca"
    ap-south-1     = "ami-96a9d3f9"
    ap-southeast-1 = "ami-40bb2123"
    ap-southeast-2 = "ami-ef051d8c"
    ca-central-1   = "ami-a1be00c5"
    eu-central-1   = "ami-eb66cf84"
    eu-west-1      = "ami-f1d22188"
    eu-west-2      = "ami-868190e2"
    sa-east-1      = "ami-9b7504f7"
    us-east-1      = "ami-a7fdcadc"
    us-east-2      = "ami-4986a62c"
    us-west-1      = "ami-4986a62c"
    us-west-2      = "ami-4da24035"
  }
}

###############################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

###############################################################

resource "aws_vpc" "default" {
  cidr_block           = "${var.network}.0.0/16"
  enable_dns_hostnames = "true"
  tags { Name = "${var.aws_vpc_name}" }
}



########   #######  ##     ## ######## #### ##    ##  ######
##     ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
##     ## ##     ## ##     ##    ##     ##  ####  ## ##
########  ##     ## ##     ##    ##     ##  ## ## ## ##   ####
##   ##   ##     ## ##     ##    ##     ##  ##  #### ##    ##
##    ##  ##     ## ##     ##    ##     ##  ##   ### ##    ##
##     ##  #######   #######     ##    #### ##    ##  ######

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}
resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
  tags { Name = "${var.aws_vpc_name}-external" }
}
resource "aws_route_table" "internal" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.nat.id}"
  }
  tags { Name = "${var.aws_vpc_name}-internal" }
}



 ######  ##     ## ########  ##    ## ######## ########  ######
##    ## ##     ## ##     ## ###   ## ##          ##    ##    ##
##       ##     ## ##     ## ####  ## ##          ##    ##
 ######  ##     ## ########  ## ## ## ######      ##     ######
      ## ##     ## ##     ## ##  #### ##          ##          ##
##    ## ##     ## ##     ## ##   ### ##          ##    ##    ##
 ######   #######  ########  ##    ## ########    ##     ######

###############################################################
# DMZ - De-militarized Zone for NAT box ONLY
#
resource "aws_subnet" "dmz" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.0.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dmz" }
}
resource "aws_route_table_association" "dmz" {
  subnet_id      = "${aws_subnet.dmz.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.dmz.subnet" {
  value = "${aws_subnet.dmz.id}"
}
output "aws.network.dmz.az" {
  value = "${var.aws_region}${var.aws_az1}"
}

###############################################################
# Private - common subnet for deployments, including CF
#
resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.1.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-private" }
}
resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.private.subnet" {
  value = "${aws_subnet.private.id}"
}
output "aws.network.private.az" {
  value = "${var.aws_region}${var.aws_az2}"
}

###############################################################
# CF Services - common subnet for deployments, including CF
#
resource "aws_subnet" "cf-services" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "${var.network}.2.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-cf-services" }
}
resource "aws_route_table_association" "cf-services" {
  subnet_id      = "${aws_subnet.cf-services.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.cf-services.subnet" {
  value = "${aws_subnet.cf-services.id}"
}
output "aws.network.cf-services.az" {
  value = "${var.aws_region}${var.aws_az3}"
}


##    ##    ###     ######  ##        ######
###   ##   ## ##   ##    ## ##       ##    ##
####  ##  ##   ##  ##       ##       ##
## ## ## ##     ## ##       ##        ######
##  #### ######### ##       ##             ##
##   ### ##     ## ##    ## ##       ##    ##
##    ## ##     ##  ######  ########  ######

resource "aws_network_acl" "hardened" {
  vpc_id = "${aws_vpc.default.id}"
  subnet_ids = [
  ]
  tags { Name = "${var.aws_vpc_name}-hardened" }


  #### ##    ##  ######   ########  ########  ######   ######
   ##  ###   ## ##    ##  ##     ## ##       ##    ## ##    ##
   ##  ####  ## ##        ##     ## ##       ##       ##
   ##  ## ## ## ##   #### ########  ######    ######   ######
   ##  ##  #### ##    ##  ##   ##   ##             ##       ##
   ##  ##   ### ##    ##  ##    ##  ##       ##    ## ##    ##
  #### ##    ##  ######   ##     ## ########  ######   ######

  # Allow ICMP Echo Reply packets (type 0)
  # (response to ping/tracepath)
  ingress {
    rule_no    = "1"
    protocol   = "icmp"
    icmp_type  = "0"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Destination Unreachable (type 3) packets
  # (host/net unreachables, port closed, fragmentation
  #  issues, etc.)
  ingress {
    rule_no    = "2"
    protocol   = "icmp"
    icmp_type  = "3"
    icmp_code  = "-1"

    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Echo packets (type 8)
  # (ping/tracepath initiator)
  ingress {
    rule_no    = "3"
    protocol   = "icmp"
    icmp_type  = "8"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Time Exceeded (type 11)
  # (tracepath TTL issue)
  ingress {
    rule_no    = "4"
    protocol   = "icmp"
    icmp_type  = "11"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  # Allow SSH traffic to the Bastion Host (in the DMZ)
  ingress {
    rule_no    = "101"
    protocol   = "tcp"
    from_port  = "22"
    to_port    = "22"
    cidr_block = "${var.jumpbox_ip}/32"
    action     = "allow"
  }

  # OTHER RULES NEEDED:
  #  - BOSH (for proto-BOSH to deploy BOSH directors)
  #  - SHIELD (for backups to/from infranet)
  #  - Bolo (to submit monitoring egress to infranet)
  #  - Concourse (either direct acccess to BOSH, or worker communication)
  #  - Vault (jumpboxen need to get to Vault for creds.  also, concourse workers)

  # All other traffic is blocked by an implicit
  # Block all other traffic.



  ########  ######   ########  ########  ######   ######
  ##       ##    ##  ##     ## ##       ##    ## ##    ##
  ##       ##        ##     ## ##       ##       ##
  ######   ##   #### ########  ######    ######   ######
  ##       ##    ##  ##   ##   ##             ##       ##
  ##       ##    ##  ##    ##  ##       ##    ## ##    ##
  ########  ######   ##     ## ########  ######   ######

  # Allow ICMP Echo Reply packets (type 0)
  # (response to ping/tracepath)
  egress {
    rule_no    = "1"
    protocol   = "icmp"
    icmp_type  = "0"
    icmp_code  = "-1"
    to_port    = "0"
    from_port  = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Destination Unreachable (type 3) packets
  # (host/net unreachables, port closed, fragmentation
  #  issues, etc.)
  egress {
    rule_no    = "2"
    protocol   = "icmp"
    icmp_type  = "3"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Echo packets (type 8)
  # (ping/tracepath initiator)
  egress {
    rule_no    = "3"
    protocol   = "icmp"
    icmp_type  = "8"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Time Exceeded (type 11)
  # (tracepath TTL issue)
  egress {
    rule_no    = "4"
    protocol   = "icmp"
    icmp_type  = "11"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow return traffic on ephemeral ports.
  # (Linux kernels use 32768-61000 for ephemeral ports)
  egress {
    rule_no    = "101"
    protocol   = "tcp"
    from_port  = "32768"
    to_port    = "65535"
    cidr_block = "0.0.0.0/0" # FIXME: lockdown to prod / bastion
    action     = "allow"
  }
  egress {
    rule_no    = "102"
    protocol   = "udp"
    from_port  = "32768"
    to_port    = "65535"
    cidr_block = "0.0.0.0/0" # FIXME: lockdown to prod / bastion
    action     = "allow"
  }

  # All other traffic is blocked by an implicit
  # DENY rule in the Network ACL (inside of AWS)
}



 ######  ########  ######          ######   ########   #######  ##     ## ########   ######
##    ## ##       ##    ##        ##    ##  ##     ## ##     ## ##     ## ##     ## ##    ##
##       ##       ##              ##        ##     ## ##     ## ##     ## ##     ## ##
 ######  ######   ##              ##   #### ########  ##     ## ##     ## ########   ######
      ## ##       ##              ##    ##  ##   ##   ##     ## ##     ## ##              ##
##    ## ##       ##    ## ###    ##    ##  ##    ##  ##     ## ##     ## ##        ##    ##
 ######  ########  ######  ###     ######   ##     ##  #######   #######  ##         ######

resource "aws_security_group" "dmz" {
  name        = "dmz"
  description = "Allow services from the private subnet through NAT"
  vpc_id      = "${aws_vpc.default.id}"
  tags { Name = "${var.aws_vpc_name}-dmz" }

  # ICMP traffic control
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow cf ssh traffic
  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow bosh registry traffic into the NAT box
  ingress {
    from_port   = 6868
    to_port     = 6868
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all traffic through the NAT from inside the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.network}.0.0/16"]
  }


  # ICMP traffic control (outbound)
  # Allows diagnostic utilities like ping / traceroute
  # to function as expected, and aid in troubleshooting.
  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow *ALL* outbound TCP traffic.
  # (security ppl may not like this...)
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow *ALL* outbound UDP traffic.
  # (security ppl may not like this...)
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "wide-open" {
  name        = "wide-open"
  description = "Allow everything in and out"
  vpc_id      = "${aws_vpc.default.id}"
  tags { Name = "${var.aws_vpc_name}-wide-open" }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "openvpn" {
  name = "openvpn"
  description = "Allow only 443 in"
  vpc_id = "${aws_vpc.default.id}"
  tags { Name = "${var.aws_vpc_name}-openvpn" }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "aws.network.sg.dmz" {
  value = "${aws_security_group.dmz.id}"
}
output "aws.network.sg.wide-open" {
  value = "${aws_security_group.wide-open.id}"
}
output "aws.network.sg.openvpn" {
  value = "${aws_security_group.openvpn.id}"
}



##    ##    ###    ########
###   ##   ## ##      ##
####  ##  ##   ##     ##
## ## ## ##     ##    ##
##  #### #########    ##
##   ### ##     ##    ##
##    ## ##     ##    ##

resource "aws_instance" "nat" {
  ami             = "${lookup(var.aws_nat_ami, var.aws_region)}"
  instance_type   = "t2.small"
  key_name        = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.dmz.id}"]
  subnet_id       = "${aws_subnet.dmz.id}"

  associate_public_ip_address = true
  source_dest_check           = false

  tags { Name = "nat" }
}

output "box.nat.public" {
  value = "${aws_instance.nat.public_ip}"
}
