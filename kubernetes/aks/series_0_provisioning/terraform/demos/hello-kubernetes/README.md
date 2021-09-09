# hello-kubernetes (basic)

This deploys a highly available `hello-kubernetes` web application using `Deployment` (3 pods) and `Service` (type `ClusterIP`).

# Requirements

  * [az](https://docs.microsoft.com/cli/azure/install-azure-cli) - provision and gather information about Azure cloud resources
  * [kubectl](https://kubernetes.io/docs/tasks/tools/) - interact with Kubernetes
  * [terraform](https://www.terraform.io/) - provisioning tool to create cloud resources

## AKS

The AKS cluster should be deployed previously, and the cluster name and resource group are known.

# Steps

## Create tf vars defaults

The clsuter_name and corresponding resource group need to match the cluster that was created earlier.  Change as appropriate.

```bash
cat <<-EOF >> $TF_VARS
resource_group_name = "aks-basic-tf"
cluster_name        = "basic"
EOF
```

## Deploy hello-kubernetes AKS Cluster

```bash
terraform init
terraform apply --var namespace="hello"
```

### Using External DNS with Service

If external-dns is installed with access to Azure DNS, you can supply the domain with the following:

```bash
terraform apply --var namespace="hello" --var domain="example.com" --var service_type="LoadBalancer"
```

If you have GNU grep† installed, you can test the results of the `LoadBalancer` with the following

```bash
DOMAIN="example.com"; URL="http://hello.${DOMAIN}"
for i in {1..20}; do
  curl --silent $URL | grep -oP 'hello-kubernetes-[^<]*|aks-[^(]*' | tr '\n' '\t'; printf "\n"
done
```

† On macOS with [Homebrew](https://brew.sh/): `brew install grep && export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"`

## Verify Deployment

```bash
# assumes KUBECONFIG is in the specified path
AZ_CLUSTER_NAME=$(awk -F'"' '/cluster_name/{ print $2 }' terraform.tfvars)
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml

kubectl get all --namespace hello
```

## Test Application locally

After running this below, you can verify using http://localhost:8080

```bash
# assumes KUBECONFIG is in the specified path
AZ_CLUSTER_NAME=$(awk -F'"' '/cluster_name/{ print $2 }' terraform.tfvars)
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml

kubectl port-forward --namespace "hello" service/hello-kubernetes 8080:80
```

# Cleanup

```bash
terraform destroy
```
