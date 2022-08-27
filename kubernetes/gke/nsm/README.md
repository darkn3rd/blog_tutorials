# NGINX Service Mesh

1. Installing NSM + KIC (NGINX+) on GKE
2. Installing Dgraph + pydgraph client
   * Dgraph: ACLs enabled for tenants
3. Installing Ingress to access Dgraph
   * certificates
   * domain name service

## 1. Provisioning Cloud Resources

### 1.0 Requirements

* Google Account with registered billing account.
* Google Cloud SDK (`gcloud`)

### 1.1 Setup env vars

Setup environment variables suitable to your environment.

```bash
cat <<-'EOF' > env.sh
export GKE_PROJECT_ID="<your-project-name-goes-here>"
export GCR_PROJECT_ID=$GKE_PROJECT_ID
export GKE_REGION="us-central1"
export GKE_CLUSTER_NAME="nsm-cluster"
export GKE_SA_NAME="worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

export KUBECONFIG=~/.kube/$REGION-$GKE_CLUSTER_NAME.yaml
EOF
```

### 1.2 Setup Projects

```bash
source env.sh

gcloud config set project $GKE_PROJECT_ID
gcloud config set compute/region $GKE_REGION

gcloud services enable "container.googleapis.com" # Enable GKE API
gcloud services enable "containerregistry.googleapis.com" # Enable GCR API

gcloud auth configure-docker
```

### 1.3 Create GSA

```bash
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

gcloud iam service-accounts create $GKE_SA_NAME \
  --display-name $GKE_SA_NAME --project $GKE_PROJECT_ID

# assign google service account to roles in GKE project
for ROLE in ${ROLES[*]}; do
  gcloud projects add-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done
```

### 1.4 Provision GKE

```bash
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"
```

### 1.5 Setup Local Authorization

```bash
gcloud container clusters  get-credentials $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION
```

## Installing NGINX Service Mesh


### 2.1 Observability
```bash
mkdir -p nsm/o11y && pushd nsm/o11y
RLS=(https://docs.nginx.com/nginx-service-mesh/examples/{prometheus,grafana,otel-collector,jaeger}.yaml)
for URL in ${URLS[*]}; do curl -sOL $URL; done
for FILE in {prometheus,grafana,otel-collector,jaeger}.yaml; do kubectl apply -f $FILE; done
popd
```

### 2.2 NGINX Service Mesh with meshctl

```bash
# download and install nginx-meshctl to $HOME/Downloads
# Instructions: https://docs.nginx.com/nginx-service-mesh/get-started/install/
pushd ~/Downloads
if [[ "$(uname -s)" == "Linux" ]]; then
  gunzip nginx-meshctl_linux.gz
  sudo mv nginx-meshctl_linux /usr/local/bin/nginx-meshctl
  sudo chmod +x /usr/local/bin/nginx-meshctl
elif  [[ "$(uname -s)" == "Darwin" ]]; then
  gunzip nginx-meshctl_darwin.gz
  sudo mv nginx-meshctl_darwin /usr/local/bin/nginx-meshctl
  sudo chmod +x /usr/local/bin/nginx-meshctl
fi
popd

# install service mesh
nginx-meshctl deploy \
  --prometheus-address "prometheus.nsm-monitoring.svc:9090" \
  --telemetry-exporters "type=otlp,host=otel-collector.nsm-monitoring.svc,port=4317" \
  --telemetry-sampler-ratio 1 \
  --disabled-namespaces "nsm-monitoring"
```

### 2.3 Kubernetes Ingress with NGINX+

```bash
# copy downloaded keys
pushd ~/Downloads
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp nginx-repo.crt /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp nginx-repo.key /etc/docker/certs.d/private-registry.nginx.com/client.key
popd

# republish images to local repository
NGINX_IC_NAP="private-registry.nginx.com/nginx-ic-nap/nginx-plus-ingress"

docker pull $NGINX_IC_NAP:2.3.0
docker tag $NGINX_IC_NAP:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0

# install helm chart using helmfile
mkdir -p nsm/nginx-ic
cat <<'EOF' > nsm/nginx-ic/helmfile.yaml
repositories:
  - name: nginx-stable
    url: https://helm.nginx.com/stable

releases:
  - name: nginx-ingress
    chart: nginx-stable/nginx-ingress
    namespace: nginx-ingress
    version: 0.14.0
    values:
      - controller:
          nginxplus: true
          image:
            repository: gcr.io/{{ requiredEnv "GCR_PROJECT_ID" }}/nginx-plus-ingress
            tag: "2.3.0"
          enableLatencyMetrics: true
        nginxServiceMesh:
          enable: true
          enableEgress: true
EOF
helmfile -f nsm/nginx-ic/helmfile.yaml apply
```


## Setup Pydgraph

```bash
curl -s https://gist.githubusercontent.com/darkn3rd/414d9525ca4f3be0a58799ec2a10f6b3/raw/c349a70300d97f8b728f3dc16714ee0c23d4df74/setup_pydgraph_gcp.sh | bash -s --
```

## Dgraph Demo

Note:

1. Part of this demonstration with pydgraph to illustration GRPC traffic requires building a custom image, which uses Docker.
2. `pydgraph-client` namespace used for python client
3. maybe `ratel-client` namespace used for ratel client


```bash
curl ${DGRAPH_ALPHA_SERVER}:8080/health | jq
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion


pushd ./examples/pydgraph
make build && make push
helmfile apply
popd

PYDGRAPH_POD=$(kubectl get pods \
  --namespace pydgraph-client \
  --output name
)
kubectl exec -ti --namespace pydgraph-client ${PYDGRAPH_POD} -- bash
```


### Generating Traffic

```bash
########
# HTTP requests
#################
curl ${DGRAPH_ALPHA_SERVER}:8080/health

########
# gRPC requests
#################
grpcurl -plaintext -proto api.proto \
 ${DGRAPH_ALPHA_SERVER}:9080 api.Dgraph/CheckVersion

########
# gRPC mutations
#################
python3 load_data.py --plaintext \
 --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
 --files ./sw.nquads.rdf \
 --schema ./sw.schema

########
# HTTP queries (DQL)
#################
curl "${DGRAPH_ALPHA_SERVER}:8080/query" --silent \
 --request POST \
 --header "Content-Type: application/dql" \
 --data $'{ me(func: has(starring)) { name } }'
```
