# Using Pod Managed Identities

In a previous section on using Azure DNS, all the pods were authorize to make changes to an Azure DNS Zone using Managed Idenities.  This is not the best security practices, as any pod running on the cluster the ability to distrupt services by changing DNS records and pointing them somewhere else.  This violates the principal of least privilege.  

An alternative is to use a feature called Pod Identities, which associates an identity that has the requried priviledges, with a service account that the pod can use.  With this, we can grant only the external-dns service account to have the correct access.


## Instructions

```bash
cat <<-EOF > env.sh
export AZ_RESOURCE_GROUP=dgraph-test
export AZ_CLUSTER_NAME=dgraph-test
export AZ_LOCATION=westus2
export AZ_DNS_DOMAIN="example.internal"
export KUBECONFIG=~/.kube/$AZ_CLUSTER_NAME
EOF

source env.sh

../script/create_cluster.sh
./enable_pod_identity.sh
./install_pod_identity.sh

../script/create_dns_zone.sh
./create_dns_sp.sh
```

# Create an identity
az group create --name myIdentityResourceGroup --location eastus
export IDENTITY_RESOURCE_GROUP="myIdentityResourceGroup"
export IDENTITY_NAME="application-identity"
az identity create --resource-group ${IDENTITY_RESOURCE_GROUP} --name ${IDENTITY_NAME}

export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query clientId -otsv)"
export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query id -otsv)"

# Assign permissions for the managed identity
NODE_GROUP=$(az aks show -g myResourceGroup -n myAKSCluster --query nodeResourceGroup -o tsv)
NODES_RESOURCE_ID=$(az group show -n $NODE_GROUP -o tsv --query "id")
az role assignment create --role "Virtual Machine Contributor" --assignee "$IDENTITY_CLIENT_ID" --scope $NODES_RESOURCE_ID

# Create Pod Identity
export POD_IDENTITY_NAME="my-pod-identity"
export POD_IDENTITY_NAMESPACE="my-app"
az aks pod-identity add --resource-group myResourceGroup --cluster-name myAKSCluster --namespace ${POD_IDENTITY_NAMESPACE}  --name ${POD_IDENTITY_NAME} --identity-resource-id ${IDENTITY_RESOURCE_ID}
```

# demo application

```bash
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: $POD_IDENTITY_NAME
spec:
  containers:
  - name: demo
    image: mcr.microsoft.com/oss/azure/aad-pod-identity/demo:v1.6.3
    args:
      - --subscriptionid=$SUBSCRIPTION_ID
      - --clientid=$IDENTITY_CLIENT_ID
      - --resourcegroup=$IDENTITY_RESOURCE_GROUP
    env:
      - name: MY_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: MY_POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: MY_POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
  nodeSelector:
    kubernetes.io/os: linux
```

## Process

On a fresh cluster, there will be this initial value:

```json
{
    "podIdentityProfile": null
}
```

After running ``:

```json
{
    "podIdentityProfile": {
        "allowNetworkPluginKubenet": null,
        "enabled": true,
        "userAssignedIdentities": null,
        "userAssignedIdentityExceptions": null
    }
}
```

After running:
```shell
az aks pod-identity add \
  --resource-group ${AZ_RESOURCE_GROUP}  \
  --cluster-name ${AZ_CLUSTER_NAME} \
  --namespace ${POD_IDENTITY_NAMESPACE} \
  --name ${POD_IDENTITY_NAME} \
  --identity-resource-id ${IDENTITY_RESOURCE_ID}
```

```json
{
    "podIdentityProfile": {
        "allowNetworkPluginKubenet": null,
        "enabled": true,
        "userAssignedIdentities": [
            {
                "bindingSelector": null,
                "identity": {
                    "clientId": "${IDENTITY_CLIENT_ID}",
                    "objectId": "${IDENTITY_PRINCIPAL_ID}",
                    "resourceId": "${IDENTITY_RESOURCE_ID}"
                },
                "name": "${POD_IDENTITY_NAME}",
                "namespace": "${POD_IDENTITY_NAMESPACE}",
                "provisioningInfo": null,
                "provisioningState": "Assigned"
            }
        ],
        "userAssignedIdentityExceptions": null
    }
}
```

# Resources

* https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
* https://hovermind.com/azure-kubernetes-service/pod-identity.html
* [Trying out the preview of Azure Active Directory pod-managed identities in Azure Kubernetes Service](https://blog.nillsf.com/index.php/2021/01/05/trying-out-the-preview-of-azure-active-directory-pod-managed-identities-in-azure-kubernetes-service/)
* https://blog.baeke.info/2020/12/09/azure-ad-pod-managed-identities-in-aks-revisited/
* https://jonathan18186.medium.com/azure-kubernetes-service-aks-with-azure-active-directory-aad-pod-identity-620cf210361e