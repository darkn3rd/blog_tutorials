# AWS EBS CSI driver

This can be installed with either the helm chart or eks-addon feature.  The later will also add snapshotter service.

You can run the scripts, or type the scripts below:

## Using Scripts

```bash
USE_EKS_ADDON=0
CHANGE_DEFAULT_SC=0

./create_esci_risa.sh
if [[ $USE_EKS_ADDON == 0 ]]; then
  ./install_esci_helm.sh
else
  ./install_esci_eksaddon.sh
fi
./create_storage_class.sh
if [[ $CHANGE_DEFAULT_SC == 0 ]]; then
  ./set_default_storage_class.h
fi
```

## Using Command Line


```bash
# irsa
eksctl create iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --attach-policy-arn $POLICY_ARN_ESCI \
  --role-only \
  --role-name $ROLE_NAME_ECSI \
  --approve

# install
if [[ $USE_EKS_ADDON == 0 ]]; then
  IRSA_KEY="eks\\.amazonaws\\.com/role-arn"
  helm repo add aws-ebs-csi-driver \
    https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  
  helm upgrade \
    --install aws-ebs-csi-driver \
    --namespace kube-system \
    --set "controller.serviceAccount.annotations.$IRSA_KEY=$ACCOUNT_ROLE_ARN_ECSI" \
    aws-ebs-csi-driver/aws-ebs-csi-driver
else
  eksctl create addon \
    --name "aws-ebs-csi-driver" \
    --cluster $EKS_CLUSTER_NAME \
    --region=$EKS_REGION \
    --service-account-role-arn $ACCOUNT_ROLE_ARN_ECSI \
    --force
fi


# storage class
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

if [[ $CHANGE_DEFAULT_SC == 0 ]]; then
  kubectl patch storageclass gp2 --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
  
  kubectl patch storageclass ebs-sc --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi
```