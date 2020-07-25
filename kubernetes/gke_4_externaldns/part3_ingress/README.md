# Part 3: Deploy a Ingress Resource


## Step 1: Deploy Application

```bash
## Create Manifest
$MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-ing.test.acme.com
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_ingress.yaml > hello_k8s_gce.yaml

## Deploy Application
kubectl apply --filename hello_k8s_gce.yaml
``` 


## Step 2: Check Results


```bash
kubectl get ingress --field-selector metadata.name=hello-k8s-gce

MY_ZONE="<your-zone-name>"  # e.g. acme-test
MY_PROJECT=$(gcloud config get-value project)

gcloud dns record-sets list \
  --project $MY_PROJECT \
  --zone $MY_ZONE \
  --filter "name~hello-ing AND type=A" \
  --format "table[box](name,type,ttl,rrdatas[0]:label=DATA)"
```

## Step 3: Run A Few Tests (optional)

We can use curl to one of three pods we deployed.

```bash
MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-ing.test.acme.com

MAX_TIMES=8
for ((i=1; i<=$MAX_TIMES; i++)); do
  curl --silent $MY_DNS_NAME | \
    awk --field-separator='>|<' '/hello-k8s-gce/{ print $3 }' 
done
```
