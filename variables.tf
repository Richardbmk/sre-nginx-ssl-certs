variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t2.micro"
}

variable "domain_name" {
  description = "The domain name for the Route53 zone"
  type        = string
  default     = "ricardoboriba.net"
}

