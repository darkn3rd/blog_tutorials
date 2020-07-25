# Part 2 Services

## Step 1: Deploy

```bash
kubectl create --filename hello_gke_extlb_deploy.yaml
kubectl create --filename hello_gke_extlb_svc.yaml
```

## Step 2: Test Connection

```bash
## show kubernetes service external IP address
kubectl get services --field-selector metadata.name=hello-gke-extlb
## show google cloud configuration
gcloud compute forwarding-rules list \
  --filter description~hello-gke-extlb \
  --format \
  "table[box](name,IPAddress,target.segment(-2):label=TARGET_TYPE)"


## get the IP address
IPADDRESS=$(gcloud compute forwarding-rules list \
  --filter description~hello-gke-extlb \
  --format="value(IPAddress)"
)

## try the URL
curl --silent http://$IPADDRESS | awk -F'[><]' '/hello-gke-extlb/{ print $3 }'
```

## Step 3: Cleanup


```bash
cat hello_gke_extlb_*.yaml | kubectl delete --filename -
```