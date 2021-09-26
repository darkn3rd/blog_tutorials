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
namespace           = "hello"
EOF
```

## Deploy `hello-kubernetes` AKS Cluster

```bash
terraform init
terraform apply --var namespace="hello"
```

### Using External DNS with `service`

If `external-dns` is installed with access to Azure DNS, you can supply the domain with the following:

```bash
terraform apply --var domain="example.com" --var service_type="LoadBalancer"
```

### Using External DNS with `ingress`

If `external-dns` is installed with access to Azure DNS along with `ingress-nginx`, you can supply the domain with the following:

```bash
terraform apply --var domain="example.com" --var enable_ingress="true" 
```

### Using Cert Manager
If `external-dns` and `cert-manager` are installed with access to Azure DNS along with `ingress-nginx`, you can supply the domain with the following:

```bash
terraform apply --var domain="example.com" --var enable_ingress="true" \
  -var enable_tls="true" --var cluster_issuer="letsencrypt-prod"
```


## Verify deployment

```bash
# assumes KUBECONFIG is in the specified path
AZ_CLUSTER_NAME=$(awk -F'"' '/cluster_name/{ print $2 }' terraform.tfvars)
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml

kubectl get all --namespace hello
```

## Test aplication locally

After running this below, you can verify using http://localhost:8080

```bash
# assumes KUBECONFIG is in the specified path
AZ_CLUSTER_NAME=$(awk -F'"' '/cluster_name/{ print $2 }' terraform.tfvars)
export KUBECONFIG=~/.kube/${AZ_CLUSTER_NAME}.yaml

kubectl port-forward --namespace "hello" service/hello-kubernetes 8080:80 &

for i in {1..20}; do
  curl --silent localhost:8080 | grep -oP 'hello-kubernetes-[^<]*|aks-[^(]*' | tr '\n' '\t'; printf "\n"
done
```

## Test application endpoint through the domain name

If you used a external load balancer (`service` or `ingress`), you can test through the domain name (assuming it's a publically registered domain name).  With GNU grep† installed, you can test the results with the following:

```bash
DOMAIN="example.com"
URL="http://hello.${DOMAIN}" # URL="https://hello.${DOMAIN}" if TLS is enabled
for i in {1..20}; do
  curl --silent $URL | grep -oP 'hello-kubernetes-[^<]*|aks-[^(]*' | tr '\n' '\t'; printf "\n"
done
```

† On macOS with [Homebrew](https://brew.sh/): `brew install grep && export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"`


# Cleanup

```bash
terraform destroy
```
