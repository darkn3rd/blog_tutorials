#!/usr/bin/env bash
source env.sh

gcloud projects remove-iam-policy-binding $DNS_PROJECT_ID \
   --member serviceAccount:$DNS_SA_EMAIL --role "roles/dns.admin"

gcloud iam service-accounts remove-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${EXTERNALDNS_NS:-"default"}/external-dns]"

gcloud iam service-accounts remove-iam-policy-binding $DNS_SA_EMAIL \
  --project $GKE_PROJECT_ID \
  --role "roles/iam.workloadIdentityUser" \
  --member "serviceAccount:$GKE_PROJECT_ID.svc.id.goog[${CERTMANAGER_NS:-"default"}/cert-manager]"

gcloud iam service-accounts delete $DNS_SA_EMAIL --project $DNS_PROJECT_ID
