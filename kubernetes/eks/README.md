
```bash
./create_cluster.sh
./get_policy.json

# kubectl client
./clients/get_kubectl_latest.sh
./clients/get_kubectl_ver.sh

# install aws_load_balancer_controller
pushd ./addons/aws_load_balancer_controller.sh
./get_policy.json
./create_albc_policy.sh
./create_albc_irsa.sh
./install_albc_helm.sh
popd

# verify
kubectl get all \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-load-balancer-controller"

# install aws_ebs_csi_driver
pushd ./addons/aws_ebs_csi_driver/
./install_esci_irsa.sh
./install_esci_helm.sh # no snapshotter

# verify
kubectl get pods \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-ebs-csi-driver"
