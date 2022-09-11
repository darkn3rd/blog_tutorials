#!/usr/bin/env bash

URLS=(https://docs.nginx.com/nginx-service-mesh/examples/{prometheus,grafana,otel-collector,jaeger}.yaml)
COMPONENT_FILE=$(mktemp)

# download Kubernetes manifests
for URL in ${URLS[*]}; do curl -sOL $URL; done

# create new helmfile.yaml
cat << EOF > ./helmfile.yaml
repositories:
  # https://artifacthub.io/packages/helm/itscontained/raw
  - name: itscontained
    url: https://charts.itscontained.io

releases:
EOF

# process Kubernetes manifests and convert them to single helmfile.yaml
for COMPONENT in {prometheus,grafana,otel-collector,jaeger}; do
  # create new component file
  cat << EOF > $COMPONENT_FILE

  ##########################
  # $COMPONENT chart
  ####################################################
  - name: $COMPONENT
    chart: itscontained/raw
    disableValidation: true
    values:
      - resources:
EOF

  # convert Kubernetes manifest to resource list items for raw helm chart values
  sed -i \
      -e 's/^/            /' \
      -e 's/.*---.*//' \
      -e 's/   apiVersion:/ - apiVersion:/' \
      $COMPONENT.yaml

  # append Helm chart section to helmfile.yaml
  cat $COMPONENT_FILE $COMPONENT.yaml >> ./helmfile.yaml
done

# remove temporary files
rm $COMPONENT_FILE {prometheus,grafana,otel-collector,jaeger}.yaml
