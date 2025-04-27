variable "region" {
  description = "The AWS region to deploy the resources in"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t2.micro"
}

variable "domain_name" {
  description = "The domain name for the Route53 zone"
  type        = string
}

variable "subdomain_name" {
  description = "The subdomain name for the Route53 record"
  type        = string
}

variable "ec2_name" {
  description = "The name of the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The name of the key pair to use for SSH access"
  type        = string
}