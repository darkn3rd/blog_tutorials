# EKS via Terraform | VPC via Terraform (Native Resources)

This project demonstrates how to provision a minimal Amazon EKS cluster using Terraform without relying on external Terraform modules.

The primary goal of this repository is educational. To keep the implementation easy to understand, many values are intentionally hard-coded and only a minimal set of variables is exposed for customization.

This repository is not intended to be production-ready. Instead, it serves as a reference for learning how the individual AWS and EKS resources fit together when building a cluster from scratch with Terraform.


## Setup

Create a `terraform.tfvars` file and define the cluster settings:

```bash
# configure var definitions
cat <<EOF > terraform.tfvars
eks_version      = "1.36"
eks_cluster_name = "mincluster"
eks_region       = "us-east-2"
EOF
```

Ensure your AWS credentials are configured before proceeding. For example:

```bash
export AWS_PROFILE=myuser
aws sts get-caller-identity
```

## Install VPC + EKS

Initialize Terraform and review the planned changes:

```bash
terraform init # only once
terraform plan 
```

Create the infrastructure:

```bash
terraform apply
```

Terraform will provision:

* A VPC
* Public and private subnets across multiple Availability Zones
* An Internet Gateway
* A NAT Gateway
* Route tables and network configuration
* An Amazon EKS cluster

## Access the K8S Cluster

```bash
mkdir -p "$HOME/.kube/aws"

export KUBECONFIG="$HOME/.kube/aws/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"

aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$EKS_REGION" \
  --kubeconfig "$KUBECONFIG"
```

## Cleanup

To remove all resources created by Terraform:

```bash
terraform destroy
```

Review the destruction plan and confirm when prompted.

## Notes

* This project is intended for learning and experimentation.
* The generated infrastructure will incur AWS charges.
* Many values are intentionally simplified or hard-coded to make the Terraform configuration easier to understand.
* No external Terraform modules are used; all resources are defined directly in this repository.