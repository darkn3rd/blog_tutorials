#!/usr/bin/env bash
# Instructions based on these docs:
# * https://docs.nginx.com/nginx-ingress-controller/installation/pulling-ingress-controller-image/

# copy files locally here
cp ~/Downloads/nginx-repo.{jwt,key,crt} .

PRIV_REG="private-registry.nginx.com"
NGINX_IC_NAP_IMAGE="$PRIV_REG/nginx-ic-nap/nginx-plus-ingress"

if [[ "$(uname -s)" == "Linux" ]]; then
  DOCKER_CERTS_PATH="/etc/docker/certs.d/$PRIV_REG"
  sudo mkdir -p $DOCKER_CERTS_PATH
  if [[ -f nginx-repo.crt || -f nginx-repo.key ]]; then
    sudo cp nginx-repo.crt $DOCKER_CERTS_PATH/client.cert
    sudo cp nginx-repo.key $DOCKER_CERTS_PATH/client.key
  fi
elif  [[ "$(uname -s)" == "Darwin" ]]; then
  DOCKER_CERTS_PATH="$HOME/.docker/certs.d/$PRIV_REG"
  mkdir -p $DOCKER_CERTS_PATH
  if [[ -f nginx-repo.crt || -f nginx-repo.key ]]; then
    cp nginx-repo.crt $DOCKER_CERTS_PATH/client.cert
    cp nginx-repo.key $DOCKER_CERTS_PATH/client.key
  fi
fi

# Restart Docker Destop
docker pull $NGINX_IC_NAP_IMAGE:2.3.0
docker tag $NGINX_IC_NAP_IMAGE:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
