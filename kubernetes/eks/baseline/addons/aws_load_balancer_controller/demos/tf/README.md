# AWS LBC Demos with Terraform

These **Terraform** modules deploy demonstration workloads to **Kubernetes**, allowing the **AWS Load Balancer Controller** to provision the corresponding AWS load balancers and related cloud resources.

## Prerequisites

* Amazon EKS Cluster
* AWS Load Balancer Controller installed
* Credentials to access the EKS cluster, usually set up via `KUBECONFIG`
* Credentials to access AWS, usually set up via `AWS_PROFILE`

## Setup

Substitute your own cluster name and region below (or export `EKS_CLUSTER_NAME`/`EKS_REGION` first and this will pick them up).

The default namespaces are chosen to match the CLI demos so that the same validation scripts can be used with either deployment method.

```bash
cat <<EOF > terraform.tfvars
eks_cluster_name = "${EKS_CLUSTER_NAME:?set EKS_CLUSTER_NAME or edit this value}"
eks_region       = "${EKS_REGION:?set EKS_REGION or edit this value}"

svc_nlb_namespace = "demo-nlb"
ing_alb_namespace = "demo-alb"
gw_nlb_namespace  = "demo-gwtcp"
gw_alb_namespace  = "demo-gwhttp"
EOF

# After creating `terraform.tfvars`, initialize the working directory:
terraform init
```

## Deploy a Single Demo

Deploying a demo causes AWS LBC to provision the corresponding AWS load balancer and supporting cloud resources.

```bash
terraform apply -target="module.svc_nlb"
terraform apply -target="module.ing_alb"
terraform apply -target="module.gw_nlb"
terraform apply -target="module.gw_alb"
```

> **NOTE**: Terraform warns whenever `-target` is used because it produces a partial apply. In this repository, that's intentional; the flag is used only to provision or destroy an individual demo.

## Deploy All Demos

```bash
terraform apply
```

## Testing

Once one or more demos are deployed, verify them end-to-end (waits for the load balancer address, waits for DNS, then curls it):

```bash
../test_demos.sh
```

## Cleanup

Destroy a single demo:

```bash
terraform destroy -target="module.svc_nlb"
```

Or you can destroy them all:

```bash
terraform destroy
```
