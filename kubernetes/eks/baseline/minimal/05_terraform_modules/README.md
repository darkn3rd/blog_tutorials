# EKS via Terraform | VPC via Terraform (Community Modules)

This project demonstrates how to provision an Amazon EKS cluster using the official Terraform AWS community modules.

Unlike the companion project that provisions every AWS resource individually, this example focuses on using well-tested, reusable Terraform modules to dramatically reduce the amount of infrastructure code while still producing a complete EKS environment.

The primary goal of this repository is educational. It demonstrates how to compose infrastructure from reusable modules rather than implementing every AWS resource manually. Only a minimal set of variables is exposed, allowing the overall architecture to remain easy to understand while highlighting the inputs required to customize a deployment.

Although the underlying modules are widely used in production environments, this repository intentionally keeps the configuration simple for learning purposes. It should be viewed as a starting point rather than a production-ready deployment

## Setup

Create a `terraform.tfvars` file and define the cluster settings:

```bash
# configure var definitions
cat <<EOF > terraform.tfvars
eks_version      = "1.36"
eks_cluster_name = "modcluster"
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
* Managed node groups
* Core EKS add-ons
* IAM roles and security groups required by the cluster

## Access the K8S Cluster

```bash
mkdir -p "$HOME/.kube/aws"

export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export EKS_REGION=$(terraform output -raw eks_region)
export KUBECONFIG="$HOME/.kube/aws/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"

aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$EKS_REGION" \
  --kubeconfig "$KUBECONFIG"
```

Verify the cluster

```bash
kubectl get nodes
kubectl get pods --all-namespaces
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
* This example demonstrates how to use reusable Terraform modules rather than creating AWS resources individually.
* The Terraform AWS modules encapsulate AWS best practices while significantly reducing the amount of infrastructure code.
* Many configuration values are intentionally simplified to keep the example concise and easy to follow.