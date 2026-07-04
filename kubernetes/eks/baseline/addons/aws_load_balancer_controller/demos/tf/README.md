# AWS LBC Demos with Terraform

These are Terraform modules that can be used to quickly bring up demos to test the AWS Load Balancer Controller.

## Prerequisites

* Amazon EKS Cluster
* AWS Load Balancer Controller installed
* Credentials to access the EKS cluster, usually set up via `KUBECONFIG`
* Credentials to access AWS, usually set up via `AWS_PROFILE`

## Setup

Substitute your own cluster name and region below (or export `EKS_CLUSTER_NAME`/`EKS_REGION` first and this will pick them up):

```bash
cat <<EOF > terraform.tfvars
eks_cluster_name = "${EKS_CLUSTER_NAME:?set EKS_CLUSTER_NAME or edit this value}"
eks_region       = "${EKS_REGION:?set EKS_REGION or edit this value}"

svc_nlb_namespace = "demo-nlb"
ing_alb_namespace = "demo-alb"
gw_nlb_namespace  = "demo-gwtcp"
gw_alb_namespace  = "demo-gwhttp"
EOF

terraform init
```

## Provision a Single Demo Load Balancer

```bash
terraform apply -target="module.svc_nlb"
terraform apply -target="module.ing_alb"
terraform apply -target="module.gw_nlb"
terraform apply -target="module.gw_alb"
```

Note: Terraform prints a warning whenever `-target` is used ("this flag is not recommended for production use"). That's expected here, for it is how we provision one demo at a time and is not a sign anything is wrong.

## Provision all Demo Load Balancers

```bash
terraform apply
```

## Testing

Once one or more demos are provisioned, verify them end-to-end (waits for the load balancer address, waits for DNS, then curls it):

```bash
../test.sh
```

## Cleanup

You can clean up a single load balancer like this:

```bash
terraform destroy -target="module.svc_nlb"
```

Or you can destroy them all:

```bash
terraform destroy
```
