output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "The public subnets of the VPC"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "The private subnets of the VPC"
  value       = module.vpc.private_subnets
}

output "security_group_id" {
  description = "The ID of the security group allowing instance access"
  value       = aws_security_group.allow_instance_access.id
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "instance_private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = aws_instance.web.private_ip
}

output "eip_allocation_id" {
  description = "The allocation ID of the Elastic IP"
  value       = aws_eip.app.id
}

output "app_url" {
  description = "The URL of the application"
  value       = aws_route53_record.app.fqdn
  
}