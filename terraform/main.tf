variable "tutor-ssh-key" {
  default     = "martivo-x220"
  type        = string
  description = "The AWS ssh key to use."
}

variable "aws-region" {
  default     = "eu-central-1"
  type        = string
  description = "The AWS Region to deploy EKS"
}

variable "kind-instance-type" {
  default     = "t3.2xlarge"
  type        = string
  description = "Worker Node EC2 instance type"
}

variable "kind-iprange" {
  default     = "10.143"
  type        = string
  description = "A and B class of the IP range 10.143 will result in 10.143.0.0/16 subnet"
}

variable "kind-route53-zone-id" {
  default     = "Z08528061CJG9I0NE3WQ"
  type        = string
  description = "Route53 domain where to create sub zones for envs"
}

variable "kind-envs" {
  default     = ["dev","test","prod"]
  type        = list
  description = "Envs to create"
}

provider "aws" {
  region = var.aws-region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.48.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "${var.kind-iprange}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
     "Name" = "lab-kind-vpc",
    }
}

data "aws_availability_zone" "a" {
  name = "${var.aws-region}a"
}


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_ami" "ubuntu-server" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
      name   = "architecture"
      values = ["x86_64"]
  }
}


resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "${var.kind-iprange}.0.0/24"
  availability_zone_id = data.aws_availability_zone.a.zone_id
  map_public_ip_on_launch = true

  tags = {
     "Name" = "lab-public-a",
    }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat-a" {
  vpc      = true
}


resource "aws_nat_gateway" "gw-a" {
  allocation_id = aws_eip.nat-a.id
  subnet_id     = aws_subnet.public-a.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "lab-gw-a"
  }
}


resource "aws_route_table" "r-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "lab-r-public"
  }
}

resource "aws_route_table_association" "ra-public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r-public.id
}


resource "aws_security_group" "allow_all" {
  name = "koolitus-kind-entigo_all"
  description = "Allow ALL traffic from ANY Source"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
   "Name" = "koolitus-kind-entigo ALL"
  }
}




# EKS Worker Nodes Resources


resource "aws_iam_role" "node" {
  name = "koolitus-kind-entigo-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}



resource "aws_iam_instance_profile" "node" {
  name = "koolitus-kind-entigo-profile"
  role = aws_iam_role.node.name
}

resource "aws_security_group" "node" {
  name        = "koolitus-kind-entigo-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
     "Name" = "koolitus-kind-entigo-sg",
    }
}

resource "aws_instance" "server" {
  for_each   = toset(var.kind-envs)
  ami           = data.aws_ami.ubuntu-server.id
  instance_type = var.kind-instance-type
  iam_instance_profile        = aws_iam_instance_profile.node.name
  key_name                    = var.tutor-ssh-key
  subnet_id = aws_subnet.public-a.id
  security_groups             = [aws_security_group.allow_all.id]
  root_block_device { 
    volume_type                 = "gp3"
    volume_size                 = 200
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "kind-${each.key}"
  }
}


data "aws_route53_zone" "dns" {
  zone_id = var.kind-route53-zone-id
}

resource "aws_route53_zone" "dns" {
  for_each   = toset(var.kind-envs)
  name = "${each.key}.${data.aws_route53_zone.dns.name}"
  tags = {
    Environment = "kind-${each.key}"
  }
}

resource "aws_route53_record" "dns-ns" {
  for_each   = toset(var.kind-envs)
  zone_id = data.aws_route53_zone.dns.zone_id
  name    = "${each.key}.${data.aws_route53_zone.dns.name}"
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.dns[each.key].name_servers
}

resource "aws_route53_record" "dns-wc" {
  for_each   = toset(var.kind-envs)
  zone_id = aws_route53_zone.dns[each.key].zone_id
  name    = "*.${aws_route53_zone.dns[each.key].name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.server[each.key].public_ip]
}
