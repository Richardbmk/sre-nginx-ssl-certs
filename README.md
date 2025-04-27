# SRE - NGINX Reverse Proxy with SSL

## Overview

The present project provides an automated solution for deploying a [simple web application](https://github.com/dockersamples/linux_tweet_app) with Nginx as a reverse proxy and SSL certificates from Let's Encrypt. The infrastructure solution is provided on AWS using Terraform, and the application components are containerized using Docker and Docker Compose, with configuration management handled by Ansible.

## Purpose

The primary goals of the project are:

- Find a way to automate the complete solution, from infra to app deploying inside the infra.
- Implement secure HTTPS access using Let's Encrypt certificates
- Highlight the benefits of using Ansible instead of EC2 User data scripts

## How it Works

1. Infrastructure Provisioning:

   - Terraform creates VPC, security groups, EC2 instance, and other resources
   - An Elastic IP is assigned to maintain a stable IP address
   - Route 53 records are created to point your domain to the instance

2. Configuration Management:

   - Ansible uses a dynamic AWS EC2 inventory to discover the newly created instance
   - Docker and Docker Compose are installed on the EC2 instance
   - Nginx is configured with HTTP initially for Let's Encrypt verification
   - SSL certificates are obtained using Let's Encrypt/Certbot
   - Final configuration switches to HTTPS with proper redirects

3. Verification:
   - The script verifies the deployment by checking HTTP to HTTPS redirection
   - It also verifies the HTTPS endpoint is accessible

## Architecture

![Architecture Diagram](./SRE-TASK-Page-1.drawio.png)

The main components of the Infrastructure solution are:

- **AWS VPC**: A virtual private network to isolate the solution in a network.
- **Security Group**: Because is a public facing application, I enable access through HTTP, HTTPS. The SSH Access main for trouble shooting and simplification of the solution.
- **Elastic IP (EIP)**: Public IP are not persistent when you start and stop an EC2 Instance, therefore to avoid this issue I'm using Elastic IP.
- **Route 53**: You need to register a domain with you chosen domain registrar. The solution only create a **A Type Record Set** inside your Hosted Zone pointing to the EIP.

The components of the the Application are:

- **App Container**: Simple web app. This container can be replaced with any type of application as long as the app container is exposed to the port 80.
- **Nginx Container**: Reverse proxy configured to listen on external ports 80 (HTTP) and 443 (HTTPS) and redirect incoming requests to the App container (Simple web app).
- **Certbot Container**: Manage SSL certificate generation and renewal.

## Technologies Used

- **Terraform**: Infrastructure as Code tool that help me to provision AWS resource automatically. I've chosen this tool because it allows me to recreate the required infra in a consistent state and to avoid using the aws console.
- **AWS**: Cloud provider for hosting the infrastructure. I've chosen AWS because it is my preferred cloud provider.
- **Ansible**: Configuration management tool for automating application deployment and configuration. I've chosen this tool, to check how [my previous setup](https://github.com/Richardbmk/sre-nginx-ssl-certs) can be improved.
- **Docker & Docker Compose**: This two tools allow us to create small VM to host and configure the application. I've chosen these tools for portability and scalability because moving the application to another Platform as a Service (PaaS) like a container orchestration (AZK, EKS, ECS, Nomand) is easier.
- **Shell Scripts**: Help me with the automation of the process. By just running a script I can deploy the end to end solution.

## Deploy solution locally

Here you will find the instructions to deploy the end to end solution on your local machine. I assume that you already have an AWS Account.

### Prerequisites

1. **AWS CLI** - Installed and configured with credentials that have the required permissions to deploy all the resources mentioned before.
2. **Terraform** - Installed and available in you PATH, so you can run terraform commands.
3. **Ansible** - Installed and available in your PATH, so you can run ansible commands.
4. **Domain Name** - A registered domain with a Route 53 hosted zone configured.
5. **Git** - You will need it to clone the project.
6. **Bash Shell** - The deployment scripts are written for Bash.

### Deployment Steps

1. Clone the repository:

```
$ git clone https://github.com/Richardbmk/sre-nginx-ssl-certs.git
$ cd sre-nginx-ssl-certs
$ git checkout ansible-setup
```

2. Make sure the deployment script is executable:

```
$ chmod +x automation-scripts/deploy.sh
```

3. Run the deployment script with the required parameters:

```
./automation-scripts/deploy.sh [REGION] [EC2_NAME] [DOMAIN_NAME] [EMAIL] [SSH_KEY_NAME]
./automation-scripts/deploy.sh us-east-1 nginxApp tweetsapp.ricardoboriba.net rdobmk@gmail.com sre-keys
```

Parameters description:

- _REGION_: AWS Region of you like to deploy the end-to-end solution. Example: "us-east-1"
- _EC2_NAME_: Tagged Name of the EC2 Instance. This is used to find the EC2 Instance ID. Example: "nginxApp"
- _DOMAIN_NAME_: Domain name for you want to use to deploy the application (must be on Route 53 that you control and own). Certbot/LetsEncrypt needed to generate the certificates. Example: "thebest.ricardoboriba.net"
- _EMAIL_: Contact email. Certbot/LetsEncrypt needed to generate the certificates. Example: "rdobmk@gmail.com"
- _SSH_KEY_NAME_: Name of the SSH Key in ~/.ssh/ directory

4. Wait for the script completion:

- The infrastructure provisioning takes around 1-3 minutes to complete.
- The application deployment takes another 2-5 minutes to fully be completed.
- The script will provide updates about the status of the deployment.

5. Access the application:

- Once the deployment is complete, use the provided domain to access the application via HTTPS.

### Troubleshooting

If the deployment fails and you are not able to access the application via HTTPS, here are a list of things to check:

1. **AWS Credentials**: Ensure your AWS credentials are valid with sufficient permissions.
2. **Ansible Inventory**: If Ansible can't find your EC2 instance:
   - Verify your EC2 instance has the correct tags matching the EC2_NAME
   - Check if the AWS region matches between Terraform and Ansible
   - Try running `export REGION=us-east-1; export EC2_NAME=nginxApp; ansible-inventory -i [aws_ec2.yml](http://\_vscodecontentref*/0) --list` manually
3. **SSH Issues**: If SSH connection fails:
   - Ensure the SSH key exists at the specified path
   - Verify security groups allow SSH access from your IP
4. **Let's Encrypt Rate Limits**: If certificate generation fails, check if you've hit [LetsEncrypt rate limits](https://letsencrypt.org/docs/rate-limits/#retrying-after-hitting-rate-limits).
5. **Logs and Status**:
   - SSH into the EC2 Instance and check Docker container logs: `docker logs certbot`
   - Check if containers are running: `docker ps`
   - Examine Nginx configuration: `docker exec -it nginx cat /etc/nginx/conf.d/default.conf`

### Clean up

To destroy all the created resources run:

```
terraform destroy -var "region=us-east-1" -var "subdomain_name=tweetsapp" -var "domain_name=ricardoboriba.net" -var "ec2_name=nginxApp" -var "key_name=sre-keys"
```

### Issues I found on this setup

- I still finding issues...
