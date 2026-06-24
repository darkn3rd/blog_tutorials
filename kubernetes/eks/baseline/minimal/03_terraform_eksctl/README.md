# EKS with Terraform and eksctl

This project demonstrates how to provision the AWS networking layer for Amazon EKS using Terraform and then create the Kubernetes cluster using eksctl.

Many organizations already have existing VPC infrastructure that must be reused rather than created by eksctl. In some environments, networking resources are shared by multiple applications. In others, network infrastructure is managed by a separate team due to security, compliance, or operational requirements. In these scenarios, EKS must be deployed into an existing VPC rather than allowing eksctl to create the networking automatically.

To simulate this workflow, Terraform is used to create the VPC, subnets, route tables, Internet Gateway, and NAT Gateway. Terraform then generates a cluster.yaml configuration that is consumed by eksctl, illustrating how to configure an EKS cluster to use existing network infrastructure.

This repository is not intended to be production-ready. Instead, it serves as a reference for understanding the relationship between Terraform-managed AWS infrastructure and an EKS cluster created with eksctl.

## Network Infrastructure Requirements

If you have existing network infrastructure and cannot use the Terraform scripts, verify that the following requirements are met before creating the EKS cluster:

* VPC
  * DNS Hostnames enabled
  * DNS Resolution enabled

* Subnets
  * At least 2 subnets across 2 Availability Zones
  * Public subnet tags:
    * `kubernetes.io/role/elb = 1`
  * Private subnet tags:
    * `kubernetes.io/role/internal-elb = 1`

* Cluster Tags (recommended)
  * `kubernetes.io/cluster/{cluster_name} = shared`
    * or
  * `kubernetes.io/cluster/{cluster_name} = owned`

* Route Tables
  * Public subnets:
    * `0.0.0.0/0 -> Internet Gateway`
  * Private subnets:
    * `0.0.0.0/0 -> NAT Gateway`

* IP Address Capacity
  * Sufficient IP addresses must be available for nodes, pods, and load balancers.

* Security Controls
  * Worker nodes must be able to communicate with required AWS services such as EKS, EC2, STS, ECR, and S3.

## Setup

Create a `terraform.tfvars` file and define the cluster settings:

```bash
# configure var definitions
cat <<EOF > terraform.tfvars
eks_version      = "1.36"
eks_cluster_name = "thecluster"
eks_region       = "us-east-2"
EOF
```

Ensure your AWS credentials are configured before proceeding. For example:

```bash
export AWS_PROFILE="myuser"
aws sts get-caller-identity
```

## Deploy VPC

Initialize Terraform and review the planned changes:

```bash
terraform init # only once
terraform plan
```

Create the network infrastructure and generate `cluster.yaml`:

```bash
terraform apply
```

Terraform will provision:

* A VPC with DNS support enabled
* Public and private subnets across multiple Availability Zones
* An Internet Gateway for public subnet access
* A NAT Gateway for outbound Internet access from private subnets
* Route tables and subnet associations
* EKS-required subnet tags for public and internal load balancer discovery
* A `cluster.yaml` configuration file for use with `eksctl`

## Deploy EKS

```bash
mkdir -p $HOME/.kube/aws/

EKS_REGION=$(awk -F'"' '/eks_region/ {print $2}' terraform.tfvars)
EKS_CLUSTER_NAME=$(awk -F'"' '/eks_cluster_name/ {print $2}' terraform.tfvars)

export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

# create Kubernetes cluster
eksctl create cluster --config-file cluster.yaml
```

## Cleanup

```bash
# Delete EKS Cluster
eksctl delete cluster --config-file cluster.yaml
# Delete EKS network infrastructure
terraform destroy
```

## Notes

* This project is intended for learning and experimentation.
* The generated infrastructure will incur AWS charges.
* Many values are intentionally simplified or hard-coded to make the examples easier to understand.
* Terraform is used to provision the VPC networking infrastructure and generate the `cluster.yaml` configuration consumed by `eksctl`.
* The examples are designed to demonstrate how EKS can be deployed into existing network infrastructure rather than relying on `eksctl` to create the networking resources automatically.
* The generated network infrastructure uses a single NAT Gateway to reduce cost and simplify the example. Production environments often deploy one NAT Gateway per Availability Zone for higher availability.
