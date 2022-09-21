

```bash
PRIV_REG="private-registry.nginx.com"
NGINX_IC_NAP_IMAGE="$PRIV_REG/nginx-ic-nap/nginx-plus-ingress"

# copy to local directory
cp ~/Downloads/nginx-repo.{jwt,key,crt} .

# Test Certficates
curl --silent \
  --key nginx-repo.key \
  --cert nginx-repo.crt \
  https://private-registry.nginx.com/v2/nginx-ic/nginx-plus-ingress/tags/list \
  | jq

curl --silent \
  --key nginx-repo.key \
  --cert nginx-repo.crt \
  https://private-registry.nginx.com/v2/nginx-ic-nap/nginx-plus-ingress/tags/list \
  | jq

# copy private certificates locally
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

# Publish Private NGINX images to GCR
docker pull $NGINX_IC_NAP_IMAGE:2.3.0
docker tag $NGINX_IC_NAP_IMAGE:2.3.0 gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
docker push gcr.io/$GCR_PROJECT_ID/nginx-plus-ingress:2.3.0
