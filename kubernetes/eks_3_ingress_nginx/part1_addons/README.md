# Installing Kubernetes Addons

## Tool Prerequisites

* `kubectl`
* `helm`
* AWS CLI `aws`

## Infrastructure Prerequisites

* Registered public domain configured in [Route53](https://aws.amazon.com/route53/)
* Registered public wildcard certficate for above domain configured in [ACM](https://aws.amazon.com/certificate-manager/) ([AWS Certificate Manager](https://aws.amazon.com/certificate-manager/))

### Route53 Notes


#### Verify Route53 Hosted Zone

You need to have register domain or sub-domain with AWS Route53 that is public. This cannot be a private certificate.  Verify that your domain is listed with `aws route53 list-hosted-zones`.

#### Verify Route53 Zone Records

With your domain configured, you can run this to see the current records set.  This is useful in monitoring records created by external-dns.

```bash
MY_DOMAIN="<your-domain-goes-here>"   # e.g. test.acme.com
## Fetch Your Zone ID
ZONE_ID=$(
  aws route53 list-hosted-zones --query "HostedZones[].[Id,Name]" --output text \
    | awk -F$'\t' "/$MY_DOMAIN./{ print \$1 }"
)

## List Current Records
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[].[join(': ',[Name,Type])]" \
  --output text
```

### ACM (AWS Certificate Manager)

You need to have a public wildcard certficate registered for the domain on [ACM](https://aws.amazon.com/certificate-manager/).

#### Verifying Public ACM Certificate

You need to verify your wildcard certficiate is created using: `aws acm list-certificates`

#### Get ACM Certificate ARN

```bash
MY_DOMAIN="<your-domain-goes-here>" # e.g. test.acme.com
MY_REGION="<region>" # e.g. us-west-2
aws acm list-certificates \
  --query "CertificateSummaryList[].[CertificateArn,DomainName]" \
  --region us-east-2 \
  --output text \
    | awk -F$'\t' "/\*.$MY_DOMAIN/{ print \$1 }"
```

#### Creating ACM Wildcard Certificate

If you haven't yet created a wild-card certificate, you can create it usng this:

```bash
MY_CERT_DOMAIN="<your-domain-goes-here>" # e.g. *.test.acme.com
MY_REGION="<region>" # e.g. us-west-2
MY_TOKEN="$(date "+%y%m%d%H%M")"
# creates public trusted certificate
aws acm request-certificate \
--domain-name  "$MY_CERT_DOMAIN" \
--validation-method DNS \
--idempotency-token $MY_TOKEN \
--options CertificateTransparencyLoggingPreference=ENABLED \
--region $MY_REGION
```

## Adding external-dns and ingress-nginx Add-ons

```bash
get_acm_arn() {
  DOMAIN=${1}
  REGION=${2}
  echo $(
    aws acm list-certificates \
      --query "CertificateSummaryList[].[CertificateArn,DomainName]" \
      --region us-east-2 \
      --output text \
        | awk -F$'\t' "/\*.$MY_DOMAIN/{ print \$1 }"
  )
}

export MY_DOMAIN="<your-domain-goes-here>" # domain registered in Route53, e.g. test.acme.com
MY_REGION="<region>" # region where cert was created, e.g. us-west-2
export MY_ACM_ARN="$(get_acm_arn $MY_DOMAIN $MY_REGION)"

## add external-dns and ingress-nginx
## add-ons are created in namespace kube-addons.
export MY_NAMESPACE="kube-addons"
./add-external-dns.sh
./add-ingress-nginx.sh
```




## Notes

To fetch the latest tag, I use

```bash
curl --silent --request GET --header 'Accept: application/json' \
 'https://registry.opensource.zalan.do/v2/teapot/external-dns/tags/list' \
   | jq -r '.tags[]' | tail -1
```
