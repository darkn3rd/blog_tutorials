# GKE 1: Building a GKE with Cloud SDK

## Step 1: Create a Cluster

Choose one: 

* `./create_basic_cluster.sh <cluster-name> <cluster-region>`
* `./create_gke_cluster.sh <cluster-name> <cluster-region>`

Check Results:

```bash
MY_CLUSTER_NAME="test-cluster"
gcloud container clusters describe $MY_CLUSTER_NAME --region us-central1
```

## Step 2: Test Cluster with Hello-Kubernetes

```bash
kubectl create --filename hello-k8s-deploy.yaml
kubectl create --filename hello-k8s-svc.yaml
```

## Step 3: Test Deployed Application

This will forward ports from one of the pods to localhost.

```bash
kubectl port-forward service/hello-basic-svc 8080:8080
```

Try it out at: http://localhost:8080

## Step 4: Cleanup


Delete Kubernetes Resources:

```bash
kubectl delete --filename hello-k8s-deploy.yaml
kubectl delete --filename hello-k8s-svc.yaml
```

Delete GKE Cluster:

```bash
MY_CLUSTER_NAME="test-cluster"
gcloud container clusters delete $MY_CLUSTER_NAME --region us-central1
```


