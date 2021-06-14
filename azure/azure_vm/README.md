# Azure Linux with VM

This section demonstrates three things:

* Terraform modules
* Azure Linux VM + Infrastructure (virutal network)

## Blog Sources

* [Getting Started on Azure VM and Infrastructure](https://joachim8675309.medium.com/azure-linux-vm-with-infra-99af44039253)

## Instructions

```bash
# create resource group
az group create --location westus --resource-group devapp
terraform apply
```

## Testing

### Get Private SSH Key

```bash
terraform output -raw tls_private_key  > azure_vm.pem
chmod 400 azure_vm.pem
```

### Using Public IP Address

```bash
terraform refresh # make sure ip address is assigned
AZURE_VM=$(terraform output -raw public_ip)
ssh azureuser@$AZURE_VM -i ./azure_vm.pem
```

## Cleanup

```bash
# destroy all terraform resources
terraform destroy

# delete resource group
az group delete devapp

# delete private key
chmod +w azure_vm.pem && rm azure_vm.pem
```
