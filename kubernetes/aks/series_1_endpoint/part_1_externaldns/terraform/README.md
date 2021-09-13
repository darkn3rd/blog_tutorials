# Terraform Azure DNS scripts

```bash
. ../env.sh
export TF_VAR_resource_group_name=$AZ_RESOURCE_GROUP
export TF_VAR_location=$AZ_LOCATION
export TF_VAR_domain=$AZ_DNS_DOMAIN

terraform init
terraform apply
```
