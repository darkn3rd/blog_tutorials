# Testing Basic GKE Functionality

These scripts can test basic funtionality the following resource objects:

* persistent volumes
* service of type LoadBalancer
* ingress
* network policies

These are adapted to run on GKE with Calico add-on installed and `ingress-gce` as the default ingress.  These can be used for other implementation of Kubernetes, but may require changes to annotations, ingress class, and service type.

The network policies were testing using the Calico CNI, but should work with other CNIs implementing network policies.

## Persistent Volume Test

```bash
# deploy test
./test_pv.sh
# verify works
kubectl get all,pvc --namespace "pv-test"
# note volume related events 
kubectl events --namespace "pv-test"
# cleanup
./delete_pv.sh
```

## External Load Balancer

```bash
# deploy test
./test_lb.sh
# verify works
kubectl get all --namespace=httpd-svc
# fetch public IP address
export SVC_LB=$(kubectl get service httpd \
  --namespace "httpd-svc" \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)
# verify forwarding rules
gcloud compute forwarding-rules list \
  --filter $SVC_LB \
  --format "table[box](name,IPAddress,target.segment(-2):label=TARGET_TYPE)"

# test web services
curl --silent --include $SVC_LB

# cleanup
./delete_lb.sh
```

## Ingress

```bash
# deploy test
./test_ing.sh
# verify works
kubectl get all,ing --namespace "httpd-ing"

# fetch public IP address
export ING_LB=$(kubectl get ing gke-ingress \
  --namespace "httpd-ing" \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

# verify forwarding rules
gcloud compute forwarding-rules list \
  --filter $ING_LB \
  --format "table[box](name,IPAddress,target.segment(-2):label=TARGET_TYPE)"

# test web services
curl --silent --include $ING_LB

# cleanup
./delete_ing.sh
```

## Network Policies

```bash
# deploy test
./test_netpol.sh

# port-forward (another tab)
kubectl port-forward service/management-ui \
  --namespace management-ui 9001

# verify on localhost:9001
echo "Verify on http://localhost:9001"

# cleanup
./delete_netpol.sh
```
