
## Create Cluster

```bash
# create cluster with OIDC provider
./eks/create_cluster.sh

# kubectl client
./clients/get_kubectl_latest.sh
./clients/get_kubectl_ver.sh

###########################################
# install aws_load_balancer_controller
###########################################
pushd ./addons/aws_load_balancer_controller
./get_policy.json
./create_albc_policy.sh
./create_albc_irsa.sh
./install_albc_helm.sh
popd

# verify
kubectl get all \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-load-balancer-controller"

###########################################
# install aws_ebs_csi_driver
###########################################
pushd ./addons/aws_ebs_csi_driver/
./install_esci_irsa.sh
./install_esci_helm.sh # no snapshotter
./create_storage_class.sh
./set_default_storage_class.sh
popd
# verify annotation looks correct
kubectl get sa ebs-csi-controller-sa --namespace "kube-system" \
  --output jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# verify pods are running 
kubectl get pods \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-ebs-csi-driver"
POD_NAME=$(kubectl get pods --namespace "kube-system" \
  --selector "app=ebs-csi-controller" \
  --output name \
  | tail -1
)
kubectl logs $POD_NAME --namespace "kube-system"
```

## Examples

```bash
# storage example
./examples/create_dgraph.sh
# ALB example
./examples/apache_httpd/alb.sh
# NLB example
./examples/apache_httpd/nlb.sh
# ELBv1 example
./examples/apache_httpd/elb.sh
```

## Delete Examples

```bash
# delete install w pvc
./examples/delete_dgraph.sh
# delete resources married to cloud resources
kubectl delete "ingress/httpd" --namespace "httpd-ing"
kubectl delete "service/httpd-svc" --namespace "httpd-svc"
kubectl delete "service/httpd" --namespace "httpd"
# delete namespace to delete resources
kubectl delete ns httpd-ing
kubectl delete ns httpd
kubectl delete ns httpd-svc
```

## Delete Cluster

```bash
./addons/aws_load_balancer_controller/delete.sh
./addons/aws_ebs_csi_driver/delete.sh
./k8s/delete_cluster.sh
```
