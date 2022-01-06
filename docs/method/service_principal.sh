# https://www.thorsten-hans.com/external-dns-azure-kubernetes-service-azure-dns/

# Create a new Service Principal
SP_CFG=$(az ad sp create-for-rbac -n $AZ_SP_NAME -o json)

# Extract essential information

SP_CLIENT_ID=$(echo $SP_CFG | jq -e -r 'select(.appId != null) | .appId')
SP_CLIENT_SECRET=$(echo $SP_CFG | jq -e -r 'select(.password != null) | .password')
SP_SUBSCRIPTIONID=$(az account show --query id -o tsv)
SP_TENANTID=$(echo $SP_CFG | jq -e -r 'select(.tenant != null) | .tenant')
