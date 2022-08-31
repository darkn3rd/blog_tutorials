
gcloud dns managed-zones create ${DNS_DOMAIN/./-} --project $DNS_PROJECT_ID \
  --description $DNS_DOMAIN --dns-name=$DNS_DOMAIN. --visibility=public

NS_LIST=$(gcloud dns record-sets list \
  --project ${DNS_PROJECT_ID} \
  --zone "${DNS_DOMAIN/./-}" \
  --name "$DNS_DOMAIN." \
  --type NS \
  --format "value(rrdatas)" \
  | tr ';' '\n'
)

echo "$NS_LIST"
