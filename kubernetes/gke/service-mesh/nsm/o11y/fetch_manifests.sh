
## Download Manfests
URLS=(https://docs.nginx.com/nginx-service-mesh/examples/{prometheus,grafana,otel-collector,jaeger}.yaml)
for URL in ${URLS[*]}; do curl -sOL $URL; done


## PROTOTYPE HEADER
cat << EOF > jaeger_header.yaml
repositories:
  # https://artifacthub.io/packages/helm/itscontained/raw
  - name: itscontained
    url: https://charts.itscontained.io

releases:
  - name: jaeger
    chart: itscontained/raw
    disableValidation: true
    values:
      - resources:
EOF

# PROTYPE EDIT
sed -i -e 's/^/            /' -e 's/.*---.*//' -e 's/   apiVersion:/ - apiVersion:/' test.yaml

# PROTOTYPE CONCAT
cat jaeger_header.yaml test.yaml > new.yaml
