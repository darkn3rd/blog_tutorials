# Core Infrastructure

```bash
# select  profile in ~/.aws/credentials
export AWS_DEFAULT_PROFILE="[your profile specified here]"
# tell terraform which profile and region
export TF_VAR_profile=$AWS_DEFAULT_PROFILE
export TF_VAR_region="us-east-2"

# create unique vars file 
cat <<-'TFVARS' > db.tfvars
database_name     = "webdb"
database_user     = "admin"
database_password = "webdb-password"
TFVARS

# initialize env - modules + aws provider
terraform init

# run the script (look before applying)
terraform plan -var-file="db.tfvars"
terraform apply -var-file="db.tfvars"
``` 
