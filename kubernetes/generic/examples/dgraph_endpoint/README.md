# Dgraph on Endpoint

This example has Dgraph accessible by an endpoint.  These environment variables will be setup for that purpose:

* `DGRAPH_HTTP` - can use DQL and GraphQL with HTTP/1.1 connections.
* `DGRAPH_GRPC` - can use DQL with gRPC (HTTP/2) sessions.

## Dgraph

Dgraph should never be accessible to the public Internet unless heavily secured, as this is a private database.

```bash
export DGRAPH_NS="dgraph"
export DGRAPH_RELEASE_NAME="dg"
export DG_ALLOW_LIST="0.0.0.0/0" # change to more secure
export DGRAPH_ZERO_DISK_SIZE="10Gi"
export DGRAPH_ALPHA_DISK_SIZE="30Gi"

# set appropriate SSD storage class for your cluster
export DGRAPH_SC="ebs-sc" # EKS (storage class defined by user)
export DGRAPH_SC="premium-rwo" # GKE (storage class installed by Google)

# install dgraph
./install_dgraph.sh
```

### Securing Dgraph inbound traffic

For quick demonstrations, you can allow everything to access Dgraph.  For more secure configuration, you may want to restrict this to the local networks of Kubernetes and remote office, such as your home or cafe, outbound IP address.

On EKS, you can run the following:

```bash
VPC_ID=$(aws eks describe-cluster \
  --name $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text
)

EKS_CIDR=$(aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --region $EKS_REGION \
  --query 'Vpcs[0].CidrBlock' \
  --output text
)

# get the current outbound IP from your current location
MY_IP_ADDRESS=$(curl --silent ifconfig.me)

# set env var to use later
export DG_ALLOW_LIST="${EKS_CIDR},${MY_IP_ADDRESS}/32"
```

On GKE, you can use the following:

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

## Testing

This is an example of testing HTTP:

```bash
# one tab
kubectl port-forward \
  --namespace $DGRAPH_NS \
  $DGRAPH_RELEASE_NAME-dgraph-alpha-headless.dgraph.svc 8080 8080

# another tab
export DGRAPH_HTTP="localhost:8080"
# test http
curl -s http://$DGRAPH_HTTP/state
```

This is an example of testing gRPC

```bash
# one tab
kubectl port-forward \
  --namespace $DGRAPH_NS \
  $DGRAPH_RELEASE_NAME-dgraph-alpha-headless.dgraph.svc 9080 9080

# another tab
export DGRAPH_GRPC="localhost:9080"
# download api.proto
curl -sOL \
  https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto

# test grpc
grpcurl -plaintext -proto api.proto $DGRAPH_GRPC api.Dgraph/CheckVersion
```

