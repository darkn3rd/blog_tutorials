# Cert Manager

This covers installing the following components:

* identity bindings for external-dns and cert-manager
* `external-dns`
* `cert-manager`
* `ingress-nginx`


## Instructions


### Add Identity Bindings

```bash
./create_pod_identities.sh
```

### Verify Identity Bindings

```bash
az aks pod-identity list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --cluster-name ${AZ_AKS_CLUSTER_NAME} \
  --query 'podIdentityProfile.userAssignedIdentities[].name' \
  --output tsv
```

### Install K8S Addons

```bash
export ACME_ISSUER_EMAIL=<your-email-address> # user@example.com
helmfile apply
helmfile --file issuers.yaml apply
```

## Demos
