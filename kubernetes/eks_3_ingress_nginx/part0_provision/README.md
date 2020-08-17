# Privision EKS

You can use any means desired to stand up an EKS cluster.

## BYOC (Bring Your Own Cluster)

You will need to add a policy to your cluster that grants access to Route53 with permissions to upsert DNS records to appropriate zones.

You can do this by:

* Worker [Node IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/worker_node_IAM_role.html)
* [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) ([IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)) and linking policy to [KSA](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) ([Kuberentes Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/))


## Using EKS Configuration Provide

A reference configuration is provided to help you provision an EKS cluster for this tutorial.

```bash
## set optional settings
MY_CLUSTER_NAME="my-demo-cluster"
MY_REGION="us-west-2"
MY_VERSION="1.14"

## create temp cluster.yaml and provision it
./create_cluster.sh $MY_CLUSTER_NAME $MY_REGION $MY_VERSION
```
