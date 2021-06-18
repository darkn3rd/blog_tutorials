# Azure Linux with VM + DNS

This section demonstrates three things:

* Terraform modules
* Azure Linux VM + Infrastructure (virutal network)
* Azure DNS

## Blog Sources

* [Getting Started on Azure VM and Infrastructure](https://joachim8675309.medium.com/azure-linux-vm-with-infra-99af44039253)
* [Managing DNS Records with Azure DNS](https://joachim8675309.medium.com/azure-linux-vm-with-dns-e54076bab296)

## Instructions: Linux VM + Public IP

```bash
# create resource group
az group create --location westus --resource-group devapp
terraform apply --target module.azure_net -target module.azure_vm
```

### Get Private SSH Key

```bash
terraform output -raw tls_private_key > azure_vm.pem
chmod 400 azure_vm.pem
```

### Test Using Public IP Address

```bash
terraform refresh # make sure ip address is assigned
AZURE_VM=$(terraform output -raw public_ip)
ssh azureuser@$AZURE_VM -i ./azure_vm.pem
```

## Scenario A: GoDaddy DNS Server

In his scenario, GoDaddy DNS server will host the domain.

### DNS Record with GoDaddy

```bash
cat <<-EOF > env.sh
export GODADDY_API_KEY="<your_api_key>"
export GODADDY_API_SECRET="<your_api_secret>"
export TF_VAR_domain="<your_domain>"
EOF

source env.sh
terraform apply --target module.godaddy_dns_record_address

curl --silent \
  --request GET "https://api.godaddy.com/v1/domains/${TF_VAR_domain}/records/A" \
  --header "accept: application/json" \
  --header  "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" | jq .[]
```

### Test Using Domain Name

```bash
ssh azureuser@appvm.${TF_VAR_domain} -i ./azure_vm.pem
```

## Scenario B: Azure DNS Server for sub-domain


1. Create sub-domain: `terraform apply --target module.azure_dns_domain`
2. Add NS records with name of `dev` that point to Azure DNS servers using [GoDaddy DNS Manager UI](https://dcc.godaddy.com/manage/dns)
3. Create A records on Azure DNS: `terraform apply --target module.azure_dns_record`

### Test Using Sub-Domain Name

```bash
ssh azureuser@appvm.dev.${TF_VAR_domain} -i ./azure_vm.pem
```

## Scenario C: Azure DNS Server to manage domain

```bash
terraform apply --target module.azure_dns_domain
terraform apply --target module.godaddy_dns_nameservers
terraform apply --target module.azure_dns_domain_record
```

### Test Using Domain Name

```bash
ssh azureuser@appvm.${TF_VAR_domain} -i ./azure_vm.pem
```

## Cleanup

### Scenario C: Azure DNS Server to manage domain

```bash
terraform destroy --target module.azure_dns_domain_record
terraform destroy --target module.azure_dns_domain
terraform destroy --target module.azure_net -target module.azure_vm
chmod +w azure_vm.pem && rm azure_vm.pem
az group delete devapp
```

In [GoDaddy DNS Manager UI](https://dcc.godaddy.com/manage/dns), the namesevers will have to be reset back to GoDaddy's nameservers

### Scenario B: Azure DNS Server for sub-domain

As NS records were created using [GoDaddy DNS Manager UI](https://dcc.godaddy.com/manage/dns), they'll have to removed in that interface.

```bash
terraform destroy --target module.azure_dns_domain
terraform destroy --target module.azure_dns_record
terraform destroy --target module.azure_net -target module.azure_vm
chmod +w azure_vm.pem && rm azure_vm.pem
az group delete devapp
```

### Scenario A: GoDaddy DNS Server

Any records created with Terraform will have to be removed through [GoDaddy DNS Manager UI](https://dcc.godaddy.com/manage/dns) due to https://github.com/n3integration/terraform-provider-godaddy/issues/45.

```bash
terraform destroy --target module.azure_net -target module.azure_vm
chmod +w azure_vm.pem && rm azure_vm.pem
az group delete devapp
```
