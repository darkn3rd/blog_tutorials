# EKS Cluster using Config File

This demonstrates how to use eksctl config files to have *Infrastructure as Code*.
The bash shell scripts create a temp `cluster.yaml` based on environment variables you set or use defaults.

## Provision

This process could take 20 minutes.

```bash
## set optional settings
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"
MY_VERSION="1.14"

## create temp cluster.yaml and provision it
./create_cluster.sh
```

## Kubernetes Configuration

You need to use these before using the cluster with `kubectl`

### Using Kubeconfig file

```bash
export KUBECONFIG="${PWD}"/demo-cluster-config.yaml
```

### Adding Credentials to ~/.kube/config


```bash
## settigns used before
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"
aws eks --region $MY_REGION update-kubeconfig --name $MY_CLUSTER_NAME
```

## Delete

This process could take 20 minutes.

```bash
## uses temporary cluster.yaml file
./delete_cluster.sh
```
