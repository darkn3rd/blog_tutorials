#!/usr/bin/env bash

DOCKER_CERTS_PATH="/etc/docker/certs.d/private-registry.nginx.com"
NGINX_IC_NAP_IMAGE="private-registry.nginx.com/nginx-ic-nap/nginx-plus-ingress"

if [[ -f nginx-repo.crt || -f nginx-repo.key ]]; then
  # Add Private NGINX credentials to Docker
  sudo mkdir -p $DOCKER_CERTS_PATH
  sudo cp nginx-repo.crt $DOCKER_CERTS_PATH/client.cert
  sudo cp nginx-repo.key $DOCKER_CERTS_PATH/client.key

  # Publish Private NGINX images to GCR
  docker pull $NGINX_IC_NAP_IMAGE:2.3.0
  docker tag $NGINX_IC_NAP_IMAGE:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
  docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
fi
