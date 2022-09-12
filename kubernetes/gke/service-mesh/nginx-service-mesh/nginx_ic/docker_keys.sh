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
