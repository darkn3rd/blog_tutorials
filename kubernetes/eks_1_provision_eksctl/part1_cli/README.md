# EKS Cluster using CLI

This demonstrates how to use eksctl cli to proision a cluster easily.
The bash shell scripts use environment variables you set or use defaults.

## Provision

This process could take 20 minutes.

```bash
## set optional settings
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"
MY_VERSION="1.14"

./create_cluster.sh $MY_CLUSTER_NAME $MY_REGION $MY_VERSION
```

## Kubernetes Configuration

### Using Kubeconfig file

```bash
export KUBECONFIG="${PWD}"/demo-cluster-config.yaml
```

### Adding Credentials to ~/.kube/config

The `eksctl` command will already update the existing `KUBECONFIG` on your current system.  
If either that configuration was absent, or you need to access it on another system, using your AWS credentials (`~/.aws/credentials`), you can update `KUBECONFIG`.

```bash
## settigns used before
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"
aws eks --region $MY_REGION update-kubeconfig --name $MY_CLUSTER_NAME
```

## Delete

This process could take 20 minutes.

```bash
## settigns used before
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"

./delete_cluster.sh $MY_CLUSTER_NAME $MY_REGION
```
