#!/usr/bin/env bash

URLS=(https://docs.nginx.com/nginx-service-mesh/examples/{prometheus,grafana,otel-collector,jaeger}.yaml)
COMPONENT_TEMP=$(mktemp)
COMPONENT_FILE=$(mktemp)
HELMFILE="helmfile.yaml"

# download Kubernetes manifests
for URL in ${URLS[*]}; do curl -sOL $URL; done

# create new helmfile.yaml
cat << EOF > $HELMFILE
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
    namespace: nsm-monitoring
    values:
      - resources:
EOF

  # convert Kubernetes manifest to resource list items for raw helm chart values
  sed -i \
      -e 's/^/            /' \
      -e 's/.*---.*//' \
      -e 's/^            apiVersion:/          - apiVersion:/' \
      $COMPONENT.yaml

  # remove blocks that create a Namespace
  grep -n -A2 -B1 "kind: Namespace" $COMPONENT.yaml \
   | sed -n 's/^\([0-9]\{1,\}\).*/\1d/p' \
   | sed -f - $COMPONENT.yaml > $COMPONENT_TEMP

  # append Helm chart section to helmfile.yaml
  cat $COMPONENT_FILE $COMPONENT_TEMP >> $HELMFILE
done

# remove temporary files
rm $COMPONENT_FILE $COMPONENT_TEMP {prometheus,grafana,otel-collector,jaeger}.yaml
