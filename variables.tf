variable "region" {
  description = "The AWS region to deploy the resources in"
  type        = string
  # default     = "us-east-1"
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t2.micro"
}

variable "domain_name" {
  description = "The domain name for the Route53 zone"
  type        = string
  # default     = "ricardoboriba.net"
}

variable "subdomain_name" {
  description = "The subdomain name for the Route53 record"
  type        = string
  # default     = "thebest"
}

