# Application

This deploys a demonistration application "hello-kubernetes" with external load balancer endpoint.

## Create Ingress from Template

```bash
sed -e "s/\$MY_DNS_NAME/$MY_DNS_NAME/" \
  template-ingress.yaml > hello-k8s-ing.yaml
```
## Deploy

```bash
cat hello-k8s-*.yaml | kubectl create --filename -
```

## Delete

```bash
cat hello-k8s-*.yaml | kubectl delete --filename -
```

## Troubleshooting

```bash
MY_DOMAIN="<your-domain-goes-here>"   # e.g. test.acme.com
MY_DNS_NAME="<your-dns-name>" # e.g. hello.test.acme.com
## Fetch Your Zone ID
ZONE_ID=$(
  aws route53 list-hosted-zones \
    --query "HostedZones[].[Id,Name]" \
    --output text | awk -F$'\t' "/$MY_DOMAIN./{ print \$1 }"
)
FILTER="ResourceRecordSets[?Name == '$MY_DNS_NAME.']|[?Type == 'A'].[Name,AliasTarget.DNSName]"


aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "$FILTER" \
  --output text
```
