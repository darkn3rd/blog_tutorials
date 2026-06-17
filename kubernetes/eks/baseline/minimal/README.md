# Minimal EKS Projects

This repository contains several examples of building a minimal Amazon EKS environment, ranging from simple deployments to more detailed infrastructure implementations.

The goal is to provide learning-focused examples that expose the underlying AWS and Kubernetes resources rather than hiding them behind large community modules.

## Components

### Network Infrastructure

* VPC
* Public and private subnets
* Internet Gateway
* NAT Gateway and Elastic IP
* Route tables, routes, and route table associations

### EKS Cluster

* EKS control plane
* Managed node groups
* EC2 launch templates
* IAM roles and policy attachments
* Pod Identity associations
* Security groups for cluster and node communication

### EKS Add-ons

* Amazon VPC CNI
* Amazon EBS CSI Driver
* Pod Identity Agent
* CoreDNS
* kube-proxy

## Repository Layout

Each project demonstrates a different approach to provisioning EKS while keeping the implementation as simple and transparent as possible.

Examples may include:

* EKS with eksctl
* EKS with AWS CLI and shell scripts
* EKS with Terraform (using External Modules)
* EKS with Terraform (No External Modules)

## Disclaimer

These projects are intended for educational purposes and are not production-ready reference architectures. Many values are intentionally simplified to make it easier to understand how the individual AWS and Kubernetes components work together.
