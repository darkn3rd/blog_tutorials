# Part 3 Ingress

## Step 1: Deploy

```bash
kubectl create --filename hello_gke_ing_deploy.yaml
kubectl create --filename hello_gke_ing_svc.yaml
kubectl create --filename hello_gke_ing_ing.yaml
```

## Step 2: Test Connection

```bash
## show kubernetes ingress resource
kubectl get ingress
## show google cloud configuration
gcloud compute forwarding-rules list \
  --filter description~hello-gke-ing \
  --format \
  "table[box](name,IPAddress,target.segment(-2):label=TARGET_TYPE)"

## get the IP address
IPADDRESS=$(gcloud compute forwarding-rules list \
  --filter description~hello-gke-ing \
  --format="value(IPAddress)"
)

## try the URL
curl --silent http://$IPADDRESS | awk -F'[><]' '/hello-gke-ing/{ print $3 }'
```


## Step 3: Cleanup


```bash
cat hello_gke_ing_*.yaml | kubectl delete --filename -
```