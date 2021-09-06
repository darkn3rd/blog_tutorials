# Using Pod Managed Identities

In a previous section on using Azure DNS, all the pods were authorize to make changes to an Azure DNS Zone using Managed Idenities.  This is not the best security practices, as any pod running on the cluster the ability to distrupt services by changing DNS records and pointing them somewhere else.  This violates the principal of least privilege.  

An alternative is to use a feature called Pod Identities, which associates an identity that has the requried priviledges, with a service account that the pod can use.  With this, we can grant only the external-dns service account to have the correct access.


## Instructions

### Create Environment Configuration

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=blog-test
export AZ_AKS_CLUSTER_NAME=blog-test
export AZ_LOCATION=westus2
export AZ_DNS_DOMAIN="example.internal"
export KUBECONFIG=~/.kube/$AZ_AKS_CLUSTER_NAME
EOF
```

### Enable Pod Identity Preview

```bash
./scripts/enable_pod_identity.sh
```

### Create AKS Cluster

```bash
source env.sh
../scripts/create_cluster.sh
./scripts/install_pod_identity.sh

../script/create_dns_zone.sh
./scripts/create_dns_sp.sh
```

```bash
az role assignment list --assignee $IDENTITY_CLIENT_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table | sed 's|/subscriptions.*providers/||' | cut -c -80
```

### Examples

Run one of these examples:

* [external-dns](examples/externaldns/README) - demonstrates deploying external-dns with access to Azure DNS
* [cert-manager](examples/cert-manager/README) - demonstrates deploying external-dns, cert-manager with access to Azure DNS and ingress-nginx.

# Resources

* https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
* https://hovermind.com/azure-kubernetes-service/pod-identity.html
* [Trying out the preview of Azure Active Directory pod-managed identities in Azure Kubernetes Service](https://blog.nillsf.com/index.php/2021/01/05/trying-out-the-preview-of-azure-active-directory-pod-managed-identities-in-azure-kubernetes-service/)
* https://blog.baeke.info/2020/12/09/azure-ad-pod-managed-identities-in-aks-revisited/
* https://jonathan18186.medium.com/azure-kubernetes-service-aks-with-azure-active-directory-aad-pod-identity-620cf210361e
