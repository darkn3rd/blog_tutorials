# GKE 1: Building GKE with Terraform


## Step 1: Initialize Environment

```bash
terraform init
```

## Step 2: Configure Variables


```bash
export TF_VAR_project=$(gcloud config get-value project)
export TF_VAR_region="us-central1"
export TF_VAR_cluster_name="my-terraform-gke-cluster"
```

## Step 3: Provision a Cluster

```bash
terraform apply
```

Watch for results:

```bash
watch gcloud container clusters list \
   --filter name=my-terraform-gke-cluster
```

## Step 4: Get Credentials

```bash
gcloud container clusters get-credentials $TF_VAR_cluster_name \
  --region $TF_VAR_region
```

Verify:

```bash
kubectl config get-contexts
```

## Step 5: Test Cluster with Hello-Kubernetes

```bash
kubectl create --filename hello-k8s-deploy.yaml
kubectl create --filename hello-k8s-svc.yaml
```

## Step 6: Test Deployed Application

This will forward ports from one of the pods to localhost.

```bash
kubectl port-forward service/hello-tf-svc 8080:8080
```

Try it out at: http://localhost:8080

## Step 7: Cleanup


Delete Kubernetes Resources:

```bash
kubectl delete --filename hello-k8s-deploy.yaml
kubectl delete --filename hello-k8s-svc.yaml
```

Delete GKE Cluster:

```bash
terraform destroy
```

Remove KUBECONFIG entry pointing to destroyed cluster:

```bash
TARGET=$(kubectl config get-contexts --output name | grep $TF_VAR_cluster_name)
kubectl config delete-context $TARGET
kubectl config delete-cluster $TARGET
```