# EKS with Terraform (no external modules)

This is an implementation of standing up an miminal EKS cluster using only Terraform without using any external module.

This is only for learning purposes where many of values are hard coded as strings, and only a minimal set of configurable variables area exposed.

## Setup

```bash
# configure var definitions
cat <<EOF > teraform.tfvars
eks_version      = "1.36"
eks_cluster_name = "mincluster"
eks_region       = "us-east-2"
```

## Install VPC + EKS

```bash
terraform init # only once
terraform plan 
terraform apply
```

## Cleanup

```bash
terraform destroy
```