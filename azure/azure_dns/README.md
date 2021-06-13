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
terraform apply --target module.dns_domain_record

curl --silent \
  -X GET "https://api.godaddy.com/v1/domains/${TF_VAR_domain}/records/A" \
  -H  "accept: application/json" \
  -H  "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" | jq .[]
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

## Cleanup

```bash
terraform destroy
az group delete devapp
```
