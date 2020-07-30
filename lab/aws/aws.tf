##
## lab/aws - A Lab Environment on AWS
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

#
# Generic Ubuntu AMI
#
# These are the region-specific IDs for an
# HVM-compatible Ubuntu image:
#
#    ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20190913
#
# The username to log into the bastion is `ubuntu'

variable "aws_ubuntu_ami" {
  default = {
    ap-east-1      = "ami-5cc9b22d"
    ap-northeast-1 = "ami-0f9af249e7fa6f61b"
    ap-northeast-2 = "ami-082bdb3b2d54d5a19"
    ap-northeast-3 = "ami-0154a1d609dece568"
    ap-south-1     = "ami-0927ed83617754711"
    ap-southeast-1 = "ami-0ee0b284267ea6cde"
    ap-southeast-2 = "ami-0328aad0f6218c429"
    ca-central-1   = "ami-06a6f79d24f2b6a21"
    eu-central-1   = "ami-050a22b7e0cf85dd0"
    eu-north-1     = "ami-7dd85203"
    eu-west-1      = "ami-03ef731cc103c9f09"
    eu-west-2      = "ami-0fab23d0250b9a47e"
    eu-west-3      = "ami-0bb607148d8cf36fb"
    me-south-1     = "ami-01011404880c390bf"
    sa-east-1      = "ami-02b235ae9b5819d3b"
    us-east-1      = "ami-04763b3055de4860b"
    us-east-2      = "ami-0d03add87774b12c5"
    us-gov-east-1  = "ami-581dfd29"
    us-gov-west-1  = "ami-339ecb52"
    us-west-1      = "ami-0dbf5ea29a7fc7e05"
    us-west-2      = "ami-0994c095691a46fb5"
  }
}

###############################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

###############################################################

resource "aws_vpc" "lab" {
  cidr_block           = "${var.network}.0.0/16"
  enable_dns_hostnames = "true"
  tags = { Name = "${var.aws_vpc_name}" }
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
  depends_on      = ["aws_internet_gateway.gw"]
  tags = { Name = "${var.aws_vpc_name}-nat" }
}
resource "aws_eip" "nat" {
  vpc = true
  tags = { Name = "${var.aws_vpc_name}-nat" }
}
output "box-nat-public" {
  value = "${aws_eip.nat.public_ip}"
}



########   #######  ##     ## ######## #### ##    ##  ######
##     ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
##     ## ##     ## ##     ##    ##     ##  ####  ## ##
########  ##     ## ##     ##    ##     ##  ## ## ## ##   ####
##   ##   ##     ## ##     ##    ##     ##  ##  #### ##    ##
##    ##  ##     ## ##     ##    ##     ##  ##   ### ##    ##
##     ##  #######   #######     ##    #### ##    ##  ######

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.lab.id}"
  tags = { Name = "${var.aws_vpc_name}-gw" }
}
resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.lab.id}"
  tags = { Name = "${var.aws_vpc_name}-external" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table" "internal" {
  vpc_id = "${aws_vpc.lab.id}"
  tags = { Name = "${var.aws_vpc_name}-internal" }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }
}

output "cc-net"    { value = "${var.network}" }
output "cc-dns"    { value = "${var.network}.0.2" }
output "cc-z1"     { value = "${var.aws_region}${var.aws_az1}" }
output "cc-region" { value = "${var.aws_region}" }



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
  vpc_id            = "${aws_vpc.lab.id}"
  cidr_block        = "${var.network}.255.192/26"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags = { Name = "${var.aws_vpc_name}-dmz" }
}
resource "aws_route_table_association" "dmz" {
  subnet_id      = "${aws_subnet.dmz.id}"
  route_table_id = "${aws_route_table.external.id}"
}
resource "aws_subnet" "dmz2" {
  vpc_id            = "${aws_vpc.lab.id}"
  cidr_block        = "${var.network}.254.192/26"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags = { Name = "${var.aws_vpc_name}-dmz2" }
}
resource "aws_route_table_association" "dmz2" {
  subnet_id      = "${aws_subnet.dmz2.id}"
  route_table_id = "${aws_route_table.external.id}"
}

###############################################################
# LAB
resource "aws_subnet" "lab" {
  vpc_id            = "${aws_vpc.lab.id}"
  cidr_block        = "${var.network}.0.0/20"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags = { Name = "${var.aws_vpc_name}-lab" }
}
resource "aws_route_table_association" "lab" {
  subnet_id      = "${aws_subnet.lab.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws-network-lab-prefix" { value = "${var.network}" }
output "aws-network-lab-cidr"   { value = "${var.network}.0.0/20" }
output "aws-network-lab-gw"     { value = "${var.network}.0.1" }
output "aws-network-lab-subnet" { value = "${aws_subnet.lab.id}" }
output "aws-network-lab-az"     { value = "${aws_subnet.lab.availability_zone}" }


 ######  ########  ######          ######   ########   #######  ##     ## ########   ######
##    ## ##       ##    ##        ##    ##  ##     ## ##     ## ##     ## ##     ## ##    ##
##       ##       ##              ##        ##     ## ##     ## ##     ## ##     ## ##
 ######  ######   ##              ##   #### ########  ##     ## ##     ## ########   ######
      ## ##       ##              ##    ##  ##   ##   ##     ## ##     ## ##              ##
##    ## ##       ##    ## ###    ##    ##  ##    ##  ##     ## ##     ## ##        ##    ##
 ######  ########  ######  ###     ######   ##     ##  #######   #######  ##         ######

resource "aws_security_group" "open-lab" {
  name        = "open-lab"
  description = "Allow everything in and out"
  vpc_id      = "${aws_vpc.lab.id}"
  tags = { Name = "${var.aws_vpc_name}-open-lab" }

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
  vpc_security_group_ids      = ["${aws_security_group.open-lab.id}"]
  subnet_id                   = "${aws_subnet.dmz.id}"
  associate_public_ip_address = true
  tags = { Name = "${var.aws_vpc_name}-bastion" }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -o /usr/local/bin/jumpbox https://raw.githubusercontent.com/starkandwayne/jumpbox/master/bin/jumpbox",
      "sudo chmod 0755 /usr/local/bin/jumpbox",
    ]
    connection {
        host = aws_instance.bastion.public_ip
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/gitconfig"
    destination = "/home/ubuntu/.gitconfig"
    connection {
        host = aws_instance.bastion.public_ip
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/tmux.conf"
    destination = "/home/ubuntu/.tmux.conf"
    connection {
        host = aws_instance.bastion.public_ip
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.aws_key_file}")}"
    }
  }
}

output "box-bastion-public" {
  value = "${aws_instance.bastion.public_ip}"
}
output "box-bastion-keyfile" {
  value = "${var.aws_key_file}"
}
