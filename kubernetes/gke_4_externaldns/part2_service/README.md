# Part 2: Deploy a Service with LoadBalancer

## Step 1: Deploy Application

```bash
## Create Manifest
$MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-svc.test.acme.com
sed "s/\$MY_DNS_NAME/$MY_DNS_NAME/" template_service.yaml > hello_k8s_lb.yaml

## Deploy Application
kubectl apply --filename hello_k8s_lb.yaml
``` 

## Step 2: Check Results

```bash
kubectl get service --field-selector metadata.name=hello-k8s-lb

MY_ZONE="<your-zone-name>"  # e.g. acme-test
MY_PROJECT=$(gcloud config get-value project) 

gcloud dns record-sets list \
  --project $MY_PROJECT  \
  --zone $MY_ZONE \
  --filter "name~hello-svc AND type=A" \
  --format "table[box](name,type,ttl,rrdatas[0]:label=DATA)"
```

## Step 3: Run A Few Tests (optional)

We can use curl to one of three pods we deployed.

```bash
MY_DNS_NAME=<name-of-dns-name>  # e.g. hello-svc.test.acme.com

MAX_TIMES=8
for ((i=1; i<=$MAX_TIMES; i++)); do
  curl --silent $MY_DNS_NAME | \
    awk --field-separator='>|<' '/hello-k8s-lb/{ print $3 }' 
done
```
