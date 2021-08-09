# AKS Provision with `az` command

## Published Blogs

* https://joachim8675309.medium.com/azure-kubernetes-service-b89cc52b7f02

## Instructions

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=dgraph-test
export AZ_CLUSTER_NAME=dgraph-test
export AZ_LOCATION=westus2
EOF

export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME
```
