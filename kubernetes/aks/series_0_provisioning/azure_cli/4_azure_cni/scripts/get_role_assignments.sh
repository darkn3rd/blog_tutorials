export AZ_AKS_IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_AKS_IDENTITY_NAME} \
  --query clientId \
  --output tsv
)

az role assignment list --assignee $AZ_AKS_IDENTITY_CLIENT_ID --all \
  --query '[].{roleDefinitionName:roleDefinitionName, provider:scope}' \
  --output table \
       | sed -e 's|/subscriptions.*resourceGroups/|:|g' \
          -e 's|/providers/|:|' \
          -e 's/Provider/:Resource Group:Provider/' \
         -e 's/^-.*-$/--------------------:--------------------:--------------------/' \
       | column -t -s:
