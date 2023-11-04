# Dgraph

Dgraph is a highly distributed graph database.


## Deploying Dgraph


### Allow List (aka Whitelist)

Below is an example how you can filter in the subnet CIDRs used for GKE and local VPC, and well as any remote office location.

```bash
SUBNET_CIDR=$(gcloud compute networks subnets describe $GKE_SUBNET_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION \
  --format json \
  | jq -r '.ipCidrRange'
)

GKE_POD_CIDR=$(gcloud container clusters describe $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION \
  --format json \
  | jq -r '.clusterIpv4Cidr'
)

# get the current outbound IP from your current location
# this will simulate the remote offic IP address
MY_IP_ADDRESS=$(curl --silent ifconfig.me)

# set env var to use later
export DG_ALLOW_LIST="${SUBNET_CIDR},${GKE_POD_CIDR},${MY_IP_ADDRESS}/32"
```

### Dgraph

```bash
./scripts/deploy_dgraph.sh
```

### Verify External Load Balancer


```bash
export DG_LB=$(kubectl get service dg-dgraph-alpha \
  --namespace dgraph \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

# verify forwarding rules
gcloud compute forwarding-rules list \
  --filter $DG_LB \
  --format "table[box](name,IPAddress,target.segment(-2):label=TARGET_TYPE)"

# test connectivity
curl --silent $DG_LB:8080/state | jq -r '.groups."1".members'
```

### Test Dgraph


#### Upload dataset

```bash
curl "$DG_LB:8080/mutate?commitNow=true" --silent --request POST --header  "Content-Type: application/json" --data $'
{
  "set": [
    {"uid": "_:luke","name": "Luke Skywalker", "dgraph.type": "Person"},
    {"uid": "_:leia","name": "Princess Leia", "dgraph.type": "Person"},
    {"uid": "_:han","name": "Han Solo", "dgraph.type": "Person"},
    {"uid": "_:lucas","name": "George Lucas", "dgraph.type": "Person"},
    {"uid": "_:irvin","name": "Irvin Kernshner", "dgraph.type": "Person"},
    {"uid": "_:richard","name": "Richard Marquand", "dgraph.type": "Person"},
    {
      "uid": "_:sw1",
      "name": "Star Wars: Episode IV - A New Hope",
      "release_date": "1977-05-25",
      "revenue": 775000000,
      "running_time": 121,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:lucas"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw2",
      "name": "Star Wars: Episode V - The Empire Strikes Back",
      "release_date": "1980-05-21",
      "revenue": 534000000,
      "running_time": 124,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:irvin"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw3",
      "name": "Star Wars: Episode VI - Return of the Jedi",
      "release_date": "1983-05-25",
      "revenue": 572000000,
      "running_time": 131,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:richard"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:st1",
      "name": "Star Trek: The Motion Picture",
      "release_date": "1979-12-07",
      "revenue": 139000000,
      "running_time": 132,
      "dgraph.type": "Film"
    }
  ]
}
' | jq
```

#### Upload Schema

```bash
curl "$DG_LB:8080/alter" --silent --request POST --data $'
name: string @index(term) .
release_date: datetime @index(year) .
revenue: float .
running_time: int .
starring: [uid] .
director: [uid] .

type Person {
  name
}

type Film {
  name
  release_date
  revenue
  running_time
  starring
  director
}
' | jq
```

#### Verify Dataseet

```bash
curl "$DG_LB:8080/query" --silent --request POST \
  --header "Content-Type: application/dql" --data $'{ me(func: has(starring)) { name } }' | jq .data

curl "$DG_LB:8080/query" --silent --request POST \
  --header "Content-Type: application/dql" --data $'
{
    me(func: allofterms(name, "Star Wars"), orderasc: release_date) 
     @filter(ge(release_date, "1980")) {
        name
        release_date
        revenue
        running_time
        director { name }
        starring (orderasc: name) { name }
    }
}
' | jq .data
```

### Visualization with Ratel

```bash
./scripts/deploy_visualization_ratel.sh
```

#### Accessing Ratel Client Application

Dgraph is accessible from an external load balancer, and Ratel is accesible through the ingress (L7 reverse proxy).  These commands will echo out the URLs that can be used to access Ratel and Dgraph.

```bash
RATEL_LB=$(kubectl get ing ratel \
  --namespace "ratel" \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

echo "http://$RATEL_LB"

DGRAPH_LB=$(kubectl get service dg-dgraph-alpha \
  --namespace dgraph \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

echo "http://$DGRAPH_LB:8080"
```

When browsing the visualization applicaiton, you can run this query and see the results:

```
{
    me(func: allofterms(name, "Star Wars"), orderasc: release_date) 
     @filter(ge(release_date, "1980")) {
        name
        release_date
        revenue
        running_time
        director { name }
        starring (orderasc: name) { name }
    }
}
```

## Securing Dgraph

### Ratel Visualization Application

Ratel is a small web service that hosts the client application.  The security policy will prevent this web service from accessing anything within the cluster.

```bash
./scripts/deploy_netpol_ratel.sh
```

#### Verify Ratel Policy

You can try this before and after deploying this policy to verify its functionality.

First, exec into the pod:

```bash
RATEL_POD=$(kubectl get pod \
  --selector app.kubernetes.io/name=ratel \
  --namespace ratel \
  --output name
)

kubectl exec -ti -n ratel $RATEL_POD -- sh
```

Then try connectivity to Dgraph:

```bash
# connect using service
wget -q -O- dg-dgraph-alpha.dgraph:8080/health
# connect using pod
wget -q -O- dg-dgraph-alpha-0.dg-dgraph-alpha-headless.dgraph:8080/health
```

### Dgraph database

```bash
# setup IP address for filtering supported IP addresses
# NOTE: This configures your current outbound IP address.  
#       Dgraph itself should be configured to whitelist this IP address.
export INGRESS_ADDRS=($(curl --silent ifconfig.me))
./scripts/deploy_netpol_dgraph.sh
```

#### Verify Dgraph Policy

##### Testing from Public IP

From your current location (assuming you are still using the same outbound IP address), you can run this:

```bash
export DG_LB=$(kubectl get service dg-dgraph-alpha --namespace dgraph \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

curl --silent $DG_LB:8080/state | jq -r '.groups."1".members'
```

##### Testing from an approved namespace

The namespace `dgraph-client` should be approved for connectivity, so you can test it with the following steps below. First create a namespace exec into curl container:

```bash
# create name spaces
kubectl create namespace dgraph-client

# run new container and exec into the container
# CTRL-D to exit the session
kubectl run curl \
  --namespace dgraph-client \
  --image=curlimages/curl \
  --stdin --tty -- sh
```

Once inside, you can run these commands:

```bash
# connect using service
curl dg-dgraph-alpha.dgraph:8080/health
# connect using pod
curl dg-dgraph-alpha-0.dg-dgraph-alpha-headless.dgraph:8080/health
```

When finished, assuming you are not using the namespace `dgraph-cleint`, you can test the test with: 

```bash
kubectl delete namespace dgraph-client
```

##### Testing from an unapproved namespace

This should not work once the policy is applied.  You can test this before applying the policy to verfy the functionality of the policy.

First createa a namespace, such as `unapproved` and deploy a curl container and exec into it:

```bash
# create name spaces
kubectl create namespace unapproved

# run new container and exec into the container
kubectl run curl \
  --namespace unapproved \
  --image=curlimages/curl \
  --stdin --tty -- sh
```

Once inside the running container, you can run the following commands below.  These should not work when the policy is applied:

```bash
# connect using service
curl dg-dgraph-alpha.dgraph:8080/health
# connect using pod
curl dg-dgraph-alpha-0.dg-dgraph-alpha-headless.dgraph:8080/health
```

When finished, you can test the test with: 

```bash
kubectl delete namespace unapproved
```
