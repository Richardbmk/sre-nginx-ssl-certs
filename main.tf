locals {
  vpc_name = "my-vpc"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  tags = {
    Name    = local.vpc_name
    Project = "nginxApp"
  }
}

resource "aws_security_group" "allow_instance_access" {
  name        = "allow_instance_access"
  description = "Allow SSH, HTTP, HTTPS Access"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "allow_instance_access"
  }
}

resource "aws_security_group_rule" "allow_https_ipv4" {
  type              = "ingress"
  description       = "HTTPS ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_instance_access.id
}

resource "aws_security_group_rule" "allow_http_ipv4" {
  type              = "ingress"
  description       = "HTTP ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_instance_access.id
}

resource "aws_security_group_rule" "allow_ssh_access" {
  type              = "ingress"
  description       = "SSH Access"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_instance_access.id
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_instance_access.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.app.id
}

resource "aws_eip" "app" {
  domain = "vpc"
}

data "aws_route53_zone" "personal" {
  name         = var.domain_name
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.personal.zone_id
  name    = "thebest"
  type    = "A"
  ttl     = 7200
  records = [aws_eip.app.public_ip]
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.allow_instance_access.id]
  subnet_id              = element(module.vpc.public_subnets, 0)

  user_data = file("${path.module}/automation-scripts/machine-initial-setup.sh")

  lifecycle {
    ignore_changes = [user_data]
  }

  tags = {
    Name = "nginxApp"
  }
}
