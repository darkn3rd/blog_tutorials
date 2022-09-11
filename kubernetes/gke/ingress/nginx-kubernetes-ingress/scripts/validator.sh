#!/usr/bin/env bash
ERROR=0
###############
# Test Required Environment Variables
#############################################
ENV_VARS=(
  ACME_ISSUER_EMAIL
  DNS_DOMAIN
  DNS_PROJECT_ID
  DNS_SA_NAME
  GCR_PROJECT_ID
  GKE_CLUSTER_NAME
  GKE_PROJECT_ID
  GKE_REGION
  GKE_SA_NAME
)

for ENV_VAR in ${ENV_VARS[*]}; do
  [[ -z "$(eval echo \$${ENV_VAR})" ]] && { echo "ERROR: command '$ENV_VAR' not found"; ERROR=1; }
done

###############
# Test Required Commands
#############################################
COMMANDS=(
  gcloud
  helm
  helmfile
  kubectl
)

# Test Commands
for COMMAND in ${COMMANDS[*]}; do
  command -v $COMMAND > /dev/null || { echo "ERROR: command '$COMMAND' not found"; ERROR=1; }
done

###############
# Exit non-zero if error occurred
#############################################
[[ "$ERROR" == 1 ]] && exit 1

echo "All required env vars found and all required commands found. Checks pass."
