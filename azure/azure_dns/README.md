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
terraform apply --target module.azure_net -target module.azure_vm
```

### DNS Record with GoDaddy

```bash
cat <<-EOF > env.sh
export GODADDY_API_KEY="<your_api_key>"
export GODADDY_API_SECRET="<your_api_secret>"
export TF_VAR_domain="<your_domain>"
EOF

source env.sh
terraform apply --target module.godaddy_dns_record

curl --silent \
  -X GET "https://api.godaddy.com/v1/domains/${TF_VAR_domain}/records/A" \
  -H  "accept: application/json" \
  -H  "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" | jq .[]
```

### DNS Records with subdomain on Azure DNS

```bash
terraform apply --target module.azure_dns_domain
## NOTE: After this is created, you need to registger NS records, e.g. "dev" and
##       point these to Azure DNS records.
## NOTE: On GoDaddy (6/2021), this see https://dcc.godaddy.com/manage/dns

terraform apply --target module.azure_dns_record
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

### Using Domain Address GoDaddy

```bash
ssh azureuser@appvm.${TF_VAR_domain} -i ./azure_vm.pem
```

### Using SubDomain Address with Azure DNS

```bash
ssh azureuser@appvm.dev.${TF_VAR_domain} -i ./azure_vm.pem
```

## Cleanup

```bash
# delete GoDaddy DNS A records
terraform apply --target module.godaddy_dns_record
# delete Azure DNS A records
terraform apply --target module.azure_dns_record
# delete Azure DNS domain or subdomain
terraform apply --target module.azure_dns_domain

# delete Azure Linux VM and network infrastructure
terraform destroy --target module.azure_net -target module.azure_vm

# delete private key
chmod +w azure_vm.pem && rm azure_vm.pem

# delete resource group
az group delete devapp
```
