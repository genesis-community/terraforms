##
## training/aws - A Lab Environment on AWS
##

variable "aws_access_key" {} # Your Access Key ID                       (required)
variable "aws_secret_key" {} # Your Secret Access Key                   (required)
variable "aws_vpc_name"   {} # Name of your VPC                         (required)
variable "aws_key_name"   {} # Name of EC2 Keypair                      (required)
variable "aws_key_file"   {} # Location of the private EC2 Keypair file (required)
variable "aws_region"     {} # AWS Region                               (required)

variable "network"        { default = "10.4" }      # First 2 octets of your /16
variable "aws_az1"        { default = "a" }
variable "aws_az2"        { default = "b" }
variable "aws_az3"        { default = "c" }

#
# Generic Ubuntu AMI
#
# These are the region-specific IDs for an
# HVM-compatible Ubuntu image:
#
#    ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20170811
#
# The username to log into the bastion is `ubuntu'

variable "aws_ubuntu_ami" {
  default = {
    ap-northeast-1 = "ami-033cdfcdd17e140cc"
    ap-northeast-2 = "ami-0b04c9bf8abfa5b89"
    ap-south-1     = "ami-0807bb2b5888ad68c"
    ap-southeast-1 = "ami-012e97ef137a3f446"
    ap-southeast-2 = "ami-0b1f854598cf629f6"
    ca-central-1   = "ami-01428c87658222f33"
    eu-central-1   = "ami-0dfd7cad24d571c54"
    eu-west-1      = "ami-0aebeb281fdee5054"
    eu-west-2      = "ami-03f2ee00e9dc6b85f"
    sa-east-1      = "ami-0389698ad66808197"
    us-east-1      = "ami-0977029b5b13f3d08"
    us-east-2      = "ami-05f39e7b7f153bc6a"
    us-west-1      = "ami-03d5270fcb641f79b"
    us-west-2      = "ami-0f47ef92b4218ec09"
  }
}

###############################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

###############################################################

resource "aws_vpc" "training" {
  cidr_block           = "${var.network}.0.0/16"
  enable_dns_hostnames = "true"
  tags { Name = "${var.aws_vpc_name}" }
}



##    ##    ###    ########
###   ##   ## ##      ##
####  ##  ##   ##     ##
## ## ## ##     ##    ##
##  #### #########    ##
##   ### ##     ##    ##
##    ## ##     ##    ##

resource "aws_nat_gateway" "nat" {
  allocation_id   = "${aws_eip.nat.id}"
  subnet_id       = "${aws_subnet.dmz.id}"
  depends_on      = ["aws_internet_gateway.default"]
  tags { Name = "nat" }
}
resource "aws_eip" "nat" {
  vpc = true
}
output "box.nat.public" {
  value = "${aws_eip.nat.public_ip}"
}



########   #######  ##     ## ######## #### ##    ##  ######
##     ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
##     ## ##     ## ##     ##    ##     ##  ####  ## ##
########  ##     ## ##     ##    ##     ##  ## ## ## ##   ####
##   ##   ##     ## ##     ##    ##     ##  ##  #### ##    ##
##    ##  ##     ## ##     ##    ##     ##  ##   ### ##    ##
##     ##  #######   #######     ##    #### ##    ##  ######

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.training.id}"
}
resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.training.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}
resource "aws_route_table" "internal" {
  vpc_id = "${aws_vpc.training.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }
}

output "cc.net"    { value = "${var.network}" }
output "cc.dns"    { value = "${var.network}.0.2" }
output "cc.z1"     { value = "${var.aws_region}${var.aws_az1}" }
output "cc.z2"     { value = "${var.aws_region}${var.aws_az2}" }
output "cc.z3"     { value = "${var.aws_region}${var.aws_az3}" }
output "cc.region" { value = "${var.aws_region}" }



 ######  ##     ## ########  ##    ## ######## ########  ######
##    ## ##     ## ##     ## ###   ## ##          ##    ##    ##
##       ##     ## ##     ## ####  ## ##          ##    ##
 ######  ##     ## ########  ## ## ## ######      ##     ######
      ## ##     ## ##     ## ##  #### ##          ##          ##
##    ## ##     ## ##     ## ##   ### ##          ##    ##    ##
 ######   #######  ########  ##    ## ########    ##     ######

###############################################################
# DMZ (NAT gws, Bastion, etc.)
resource "aws_subnet" "dmz" {
  vpc_id            = "${aws_vpc.training.id}"
  cidr_block        = "${var.network}.255.192/26"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dmz" }
}
resource "aws_route_table_association" "dmz" {
  subnet_id      = "${aws_subnet.dmz.id}"
  route_table_id = "${aws_route_table.external.id}"
}

###############################################################
# OPS (BOSH, Vault, etc.)
resource "aws_subnet" "ops" {
  vpc_id            = "${aws_vpc.training.id}"
  cidr_block        = "${var.network}.0.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-ops" }
}
resource "aws_route_table_association" "ops" {
  subnet_id      = "${aws_subnet.ops.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.ops.prefix" { value = "${var.network}.0" }
output "aws.network.ops.cidr"   { value = "${var.network}.0.0/24" }
output "aws.network.ops.gw"     { value = "${var.network}.0.1" }
output "aws.network.ops.subnet" { value = "${aws_subnet.ops.id}" }
output "aws.network.ops.az"     { value = "${aws_subnet.ops.availability_zone}" }

resource "aws_subnet" "concourse1" {
  vpc_id            = "${aws_vpc.training.id}"
  cidr_block        = "${var.network}.1.0/26"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-concourse" }
}
resource "aws_route_table_association" "concourse1" {
  subnet_id      = "${aws_subnet.concourse1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.concourse1.prefix" { value = "${var.network}.1" }
output "aws.network.concourse1.cidr"   { value = "${var.network}.1.0/26" }
output "aws.network.concourse1.gw"     { value = "${var.network}.1.1" }
output "aws.network.concourse1.subnet" { value = "${aws_subnet.concourse1.id}" }
output "aws.network.concourse1.az"     { value = "${aws_subnet.concourse1.availability_zone}" }

resource "aws_subnet" "concourse2" {
  vpc_id            = "${aws_vpc.training.id}"
  cidr_block        = "${var.network}.1.64/26"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-concourse" }
}
resource "aws_route_table_association" "concourse2" {
  subnet_id      = "${aws_subnet.concourse2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.concourse2.prefix" { value = "${var.network}.1" }
output "aws.network.concourse2.cidr"   { value = "${var.network}.1.64/26" }
output "aws.network.concourse2.gw"     { value = "${var.network}.1.65" }
output "aws.network.concourse2.subnet" { value = "${aws_subnet.concourse2.id}" }
output "aws.network.concourse2.az"     { value = "${aws_subnet.concourse2.availability_zone}" }

resource "aws_subnet" "concourse3" {
  vpc_id            = "${aws_vpc.training.id}"
  cidr_block        = "${var.network}.1.128/26"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-concourse" }
}
resource "aws_route_table_association" "concourse3" {
  subnet_id      = "${aws_subnet.concourse3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.concourse3.prefix" { value = "${var.network}.1" }
output "aws.network.concourse3.cidr"   { value = "${var.network}.1.128/26" }
output "aws.network.concourse3.gw"     { value = "${var.network}.1.129" }
output "aws.network.concourse3.subnet" { value = "${aws_subnet.concourse3.id}" }
output "aws.network.concourse3.az"     { value = "${aws_subnet.concourse3.availability_zone}" }



 ######  ########  ######          ######   ########   #######  ##     ## ########   ######
##    ## ##       ##    ##        ##    ##  ##     ## ##     ## ##     ## ##     ## ##    ##
##       ##       ##              ##        ##     ## ##     ## ##     ## ##     ## ##
 ######  ######   ##              ##   #### ########  ##     ## ##     ## ########   ######
      ## ##       ##              ##    ##  ##   ##   ##     ## ##     ## ##              ##
##    ## ##       ##    ## ###    ##    ##  ##    ##  ##     ## ##     ## ##        ##    ##
 ######  ########  ######  ###     ######   ##     ##  #######   #######  ##         ######

resource "aws_security_group" "open" {
  name        = "open"
  description = "Allow everything in and out"
  vpc_id      = "${aws_vpc.training.id}"
  tags { Name = "${var.aws_vpc_name}-open" }

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



########     ###     ######  ######## ####  #######  ##    ##
##     ##   ## ##   ##    ##    ##     ##  ##     ## ###   ##
##     ##  ##   ##  ##          ##     ##  ##     ## ####  ##
########  ##     ##  ######     ##     ##  ##     ## ## ## ##
##     ## #########       ##    ##     ##  ##     ## ##  ####
##     ## ##     ## ##    ##    ##     ##  ##     ## ##   ###
########  ##     ##  ######     ##    ####  #######  ##    ##

resource "aws_instance" "bastion" {
  ami                         = "${lookup(var.aws_ubuntu_ami, var.aws_region)}"
  instance_type               = "t2.small"
  key_name                    = "${var.aws_key_name}"
  vpc_security_group_ids      = ["${aws_security_group.open.id}"]
  subnet_id                   = "${aws_subnet.dmz.id}"
  associate_public_ip_address = true

  tags { Name = "${var.aws_vpc_name}-bastion" }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -o /usr/local/bin/jumpbox https://raw.githubusercontent.com/starkandwayne/jumpbox/master/bin/jumpbox",
      "sudo chmod 0755 /usr/local/bin/jumpbox",
      #"sudo jumpbox system"
    ]
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/gitconfig"
    destination = "/home/ubuntu/.gitconfig"
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/tmux.conf"
    destination = "/home/ubuntu/.tmux.conf"
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
}

output "box.bastion.public" {
  value = "${aws_instance.bastion.public_ip}"
}
output "box.bastion.keyfile" {
  value = "${var.aws_key_file}"
}
