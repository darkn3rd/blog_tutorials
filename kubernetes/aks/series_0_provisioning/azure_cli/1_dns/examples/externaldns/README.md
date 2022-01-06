# External DNS via Helmfile


This uses the tool helmfile to manage deployment of solutions with the `helm` tool.  This will use Bitnami's external-dns helm chart.

## Required Tools

* Helmfile: https://github.com/roboll/helmfile
* Helm: https://helm.sh/
  * helm-diff: https://github.com/databus23/helm-diff
* Kubernetes Client: https://kubernetes.io/docs/tasks/tools/
* Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli

## Instructions

```bash
export AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
export AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
helmfile apply
```
