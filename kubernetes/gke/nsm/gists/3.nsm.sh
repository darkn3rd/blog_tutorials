##############
# STEP 1: Install Observability Tools
#########################
RLS=(https://docs.nginx.com/nginx-service-mesh/examples/{prometheus,grafana,otel-collector,jaeger}.yaml)
for URL in ${URLS[*]}; do curl -sOL $URL; done
for FILE in {prometheus,grafana,otel-collector,jaeger}.yaml; do kubectl apply -f $FILE; done

##############
# STEP 2: Install NGINX Service Mesh
#########################
nginx-meshctl deploy \
  --prometheus-address "prometheus.nsm-monitoring.svc:9090" \
  --telemetry-exporters "type=otlp,host=otel-collector.nsm-monitoring.svc,port=4317" \
  --telemetry-sampler-ratio 1 \
  --disabled-namespaces "nsm-monitoring"

##############
# STEP 3: Add Private NGINX credentials to Docker
#########################
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp nginx-repo.crt /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp nginx-repo.key /etc/docker/certs.d/private-registry.nginx.com/client.key

##############
# STEP 4: Publish Private NGINX images to GCR
#########################
NGINX_IC_NAP="private-registry.nginx.com/nginx-ic-nap/nginx-plus-ingress"

docker pull $NGINX_IC_NAP:2.3.0
docker tag $NGINX_IC_NAP:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0

##############
# STEP 5: Deploy Ingress Controller
#########################
cat << EOF > nginxplus.yaml
controller:
  nginxplus: true
  image:
    repository: gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress
    tag: "2.3.0"
  enableLatencyMetrics: true
nginxServiceMesh:
  enable: true
  enableEgress: true
EOF

# Deploy ingress
helm install \
  --namespace nginx-ingress \
  --values nginxplus.yaml \
  nginx-ingress \
  nginx-stable/nginx-ingress
