# Azure Linux with VM + DNS

This section demonstrates three things:

* Terraform modules
* Azure Linux VM + Infrastructure (virutal network)
* Azure DNS

## Blog Sources

* [Getting Started on Azure VM and Infrastructure](https://joachim8675309.medium.com/azure-linux-vm-with-infra-99af44039253)

## Instructions

```bash
# create resource group
az group create --location westus --resource-group devapp
terraform apply
```

## Cleanup

```bash
terraform destroy
az group delete devapp
```
