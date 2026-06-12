# EKSCTL with Existing VPC usign Terraform

```bash
export AWS_PROFILE="myprofile" # change

# set desired variable values
cat <<EOF > terraform.tfvars
eks_version      = "1.35"
eks_cluster_name = "mycluster"
eks_region       = "us-east-2"
EOF

# create EKS network infrastructure
terraform init # only once
terraform plan
terraform apply

mkdir -p $HOME/.kube/aws/
EKS_REGION=$(awk -F'"' '/eks_region/ {print $2}' terraform.tfvars)
EKS_CLUSTER_NAME=$(awk -F'"' '/eks_cluster_name/ {print $2}' terraform.tfvars)
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

# create Kubernetes cluster
eksctl create cluster -f cluster.yaml
```
