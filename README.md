# SRE - NGINX Reverse Proxy with SSL

## Overview

The present project provides an automated solution for deploying a [simple web application](https://github.com/dockersamples/linux_tweet_app) with Nginx as a reverse proxy and SSL certificates from Let's Encrypt. The infrastructure solution is provided on AWS using Terraform, and the application components are containerized using Docker and Docker Compose.

## Purpose

The primary goals of the project are:

- Find a way to automate the complete solution, from infra to app deploying inside the infra.
- Implement secure HTTPS access using Let's Encrypt certificates

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
- **Docker & Docker Compose**: This two tools allow us to create small VM to host and configure the application. I've chosen these tools for portability and scalability because moving the application to another Platform as a Service (PaaS) like a container orchestration (AZK, EKS, ECS, Nomand) is easier.
- **Shell Scripts**: Help me with the automation of the process. By just running a script I can deploy the end to end solution.
- **EC2 User data**: Allows me to configure the EC2 Instance with the simple web application.

## Get Started
