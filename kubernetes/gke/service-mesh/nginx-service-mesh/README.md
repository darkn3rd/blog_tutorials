# NGINX Service Mesh

This tutorial will be divided into two parts, due to necessary complexity involved in both using the service mesh itself for east-west traffic and the endpoint ingress for NGINX ingress controller with support for DNS and certificates.

 * Part 1
   * Cloud Resources
     * Google Kubernetes Engine
     * Google Contianer Registry
   * Kubernetes Resources
     * o11y (observability)
       * Jaeger
       * OpenTelemetry Collector
       * Prometheus
       * Grafana
     * nsm (NGINX service mesh)
 * Part 2
   * Cloud Resources
     * Google Cloud DNS zone
   * Kubenetes Components
     * external-dns
     * cert-manager
     * kubernetes-ingress (NGINX ingress controller)


## Part 1: NGINX Service Mesh overview

1. Observability
2. NGINX service mesh in strict mode
3. Dgraph demo
   * show that non-mesh traffic doesn't work
   * show that mesh traffic works

## Part 2: NGINX Ingress Controller overview


1. Install Kubernetes addons in the following order:
   * CertManager - automates installing certificates
   * NGINX+ Ingress Controller - integrates into NSM, requires NGINX+ license
   * ExternalDNS - automates updating DNS records
2. Access Endpoint Demo
   * demonstrate access with `grpcurl` and `curl`
   * demonstrate visualization with Ratel


# Instructions

## Prerequisites

The following tools are needed:

* `nginx-meshctl`
* `kubectl`
* `helm`
* `helmfile`
* `gcloud`

## Part 1: NGINX Service Mesh

1. Configure appropriate `env.sh` and source it. See `./scripts/part_1/example.env.sh`
2. Setup project structure: `./scripts/part_1/setup.sh`
3. Enable Projects: `./scripts/part_1/project.sh`
4. Create GKE cluster: `./scripts/part_1/gke.sh`
5. Enabled GCR: `./scripts/part_1/gcr.sh`
6. Deploy NSM with observability:
   ```bash
   pushd o11y && ./fetch_manifests.sh && popd
   helmfile --file ./o11y/helmfile.yaml apply
   export NSM_ACCESS_CONTROL_MODE=allow # deny causes problems
   helmfile --file ./nsm/helmfile.yaml apply
   ```
7. Deploy Dgraph database service with manual injection:
   ```bash
   kubectl get namespace "dgraph" > /dev/null 2> /dev/null \
    || kubectl create namespace "dgraph" \
    && kubectl label namespaces "dgraph" name="dgraph"

   helmfile --file dgraph/helmfile.yaml template \
    | nginx-meshctl inject \
        --ignore-incoming-ports 5080,7080 \
        --ignore-outgoing-ports 5080,7080 \
    | kubectl apply --namespace "dgraph" --filename -
    ```
7. Build-Publish Containers:
   ```bash
   pushd ./clients
   bash /fetch_scripts.sh
   pushd ./examples/pydgraph
   make build
   make push
   popd
   popd
   ```
8. Deploy pygraph-client that is part of Mesh (positive test)
   ```bash
   kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null \
    || kubectl create namespace "pydgraph-client" \
    && kubectl label namespaces "pydgraph-client" name="pydgraph-client"

   helmfile --file ./clients/examples/pydgraph/helmfile.yaml template \
     | nginx-meshctl inject \
     | kubectl apply --namespace "pydgraph-client" --filename -
   ```
8. Deploy pygraph-client that is NOT PART OF MESH (negative test)
   ```bash
   helmfile \
     --file ./clients/examples/pydgraph/helmfile.yaml \
     --namespace "pydgraph-no-mesh" \
     apply
   ```
9. Negative Test: Execute into Container
   ```bash
   export CLIENT_NAMESPACE="pydgraph-no-mesh"
   # Exec into pydgraph-client
   PYDGRAPH_POD=$(
     kubectl get pods --namespace $CLIENT_NAMESPACE --output name
   )

   kubectl exec -ti \
     --container "pydgraph-client" \
     --namespace $CLIENT_NAMESPACE \
     ${PYDGRAPH_POD} -- bash
   ```
10. Run Negative Test
    ```bash
    # test gRPC (should fail)
    grpcurl -plaintext -proto api.proto \
      ${DGRAPH_ALPHA_SERVER}:9080 \
      api.Dgraph/CheckVersion

    # test HTTP connection (should fail)
    curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health
    echo $?
    curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state
    echo $?

    # Load Data with pydgraph-client (should fail)
    python3 load_data.py \
      --plaintext \
      --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
      --files ./sw.nquads.rdf \
      --schema ./sw.schema

    logout
    ```
11. Positive Test: Execute into Container
    ```bash
    export CLIENT_NAMESPACE="pydgraph-client"
    # Exec into pydgraph-client
    PYDGRAPH_POD=$(
      kubectl get pods --namespace $CLIENT_NAMESPACE --output name
    )

    kubectl exec -ti \
      --container "pydgraph-client" \
      --namespace $CLIENT_NAMESPACE \
      ${PYDGRAPH_POD} -- bash
    ```
12. Run Postive Test
    ```bash
    # test gRPC connection
    grpcurl -plaintext -proto api.proto \
      ${DGRAPH_ALPHA_SERVER}:9080 \
      api.Dgraph/CheckVersion

    # test HTTP connection
    curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
    curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq

    #######################
    # Load Data with pydgraph-client
    ##########################################
    python3 load_data.py \
      --plaintext \
      --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
      --files ./sw.nquads.rdf \
      --schema ./sw.schema
    ```

## Part 2: Integrated Service Mesh

1. Configure appropriate `env.sh` and source it. See `./scripts/part_2/example.env.sh`
2. Setup project structure: `./scripts/part_2/setup.sh`
3. Enable Projects: `./scripts/part_1/project.sh`
4. Setup Workload Identity : `./scripts/part_1/wi.sh`
5. Install CertManager
   ```bash
   helmfile --file ./kube_addons/cert_manager/helmfile.yaml apply
   helmfile --file ./kube_addons/cert_manager/issuers.yaml apply
   ```
6. Republish NGINX+ Ingress Controller images
   ```bash
   source env.sh
   PRIV_REG="private-registry.nginx.com"
   if [[ "$(uname -s)" == "Linux" ]]; then
     DOCKER_CERTS_PATH="/etc/docker/certs.d/$PRIV_REG"
     sudo mkdir -p $DOCKER_CERTS_PATH
   elif  [[ "$(uname -s)" == "Darwin" ]]; then
     DOCKER_CERTS_PATH="$HOME/.docker/certs.d/$PRIV_REG"
     mkdir -p $DOCKER_CERTS_PATH
   fi

   if [[ -f nginx-repo.crt || -f nginx-repo.key ]]; then
     cp nginx-repo.crt $DOCKER_CERTS_PATH/client.cert
     cp nginx-repo.key $DOCKER_CERTS_PATH/client.key
   fi

   NGINX_IC_NAP_IMAGE="$PRIV_REG/nginx-ic-nap/nginx-plus-ingress"
   docker pull $NGINX_IC_NAP_IMAGE:2.3.0
   docker tag $NGINX_IC_NAP_IMAGE:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
   docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
   ```
7. Install NGINX+ Ingress Controller
   ```bash
   export NGINX_APP_PROTECT=true
   helmfile --file ./kube_addons/nginx_ic/helmfile.yaml apply
   ```
8. Install ExternalDNS
   ```bash
   helmfile --file ./kube_addons/external_dns/helmfile.yaml apply
   ```
9. Install Ratel
   ```bash
   kubectl get namespace "ratel" > /dev/null 2> /dev/null \
    || kubectl create namespace "ratel" \
    && kubectl label namespaces "ratel" name="ratel"

   helmfile --file ratel/helmfile.yaml template \
     | nginx-meshctl inject \
     | kubectl apply --namespace "ratel" --filename -
   ```
10. Deploy Virtual Server
    ```bash
    helmfile --file ./ratel/vs.yaml apply
    export MY_IP_ADDRESS=$(curl --silent ifconfig.me)
    helmfile --file ./dgraph/vs.yaml apply
    ```
11. Test Virtual Server
    ```bash
    curl dgraph.${DNS_DOMAIN}/health | jq
    curl dgraph.${DNS_DOMAIN}/state | jq

    curl -sOL https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto api.proto
    grpcurl -proto api.proto grpc.$DNS_DOMAIN:443 api.Dgraph/CheckVersion
    ```

## Part 3: SMI Traffic Access

This is experimental and under development

1. Patch NSM to deny all traffic
   ```bash
   export NSM_ACCESS_CONTROL_MODE=deny
   helmfile --file ./nsm/helmfile.yaml apply
   kubectl delete --namespace "nginx-mesh" \
     $(kubectl get pods --namespace "nginx-mesh" --selector "app.kubernetes.io/name=nginx-mesh-api" --output name)
   nginx-meshctl config | jq -r .accessControlMode
   ```
2. Exec into Client Container
   ```bash
   export CLIENT_NAMESPACE="pydgraph-client"
   PYDGRAPH_POD=$(kubectl get pods --namespace $CLIENT_NAMESPACE --output name)
   kubectl exec -ti \
     --container "pydgraph-client" \
     --namespace $CLIENT_NAMESPACE \
     ${PYDGRAPH_POD} -- bash
   ```
3. Negative Test:
   ```bash
   # SHOULD FAIL (but does not)
   grpcurl -plaintext -proto api.proto \
     ${DGRAPH_ALPHA_SERVER}:9080 \
     api.Dgraph/CheckVersion

   # SHOULD FAIL
   curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health
   curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state
   logout
   ```
4. Patch Ratel
   ```bash
   NSM_ACCESS_CONTROL_MODE=$(nginx-meshctl config | jq -r .accessControlMode)
   helmfile --file ratel/vs.yaml apply
   ```
5. Patch Dgraph Server (Dgraph Needs ServiceAccount Support - NOT YET IMPLEMENTED)
   ```bash
   NSM_ACCESS_CONTROL_MODE=$(nginx-meshctl config | jq -r .accessControlMode)
   helmfile --file ./dgraph/vs.yaml apply
   ```
5. Patch Pydgraph Client (NOT YET IMPLEMENTED)
   ```bash
   NSM_ACCESS_CONTROL_MODE=$(nginx-meshctl config | jq -r .accessControlMode)
   helmfile --file access.yaml apply
   ```
