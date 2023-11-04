# Ultimate Baseline EKS (eksctl)

This is part of a series to setup a secure baseline Kubernetes cluster with EKS.  This tutorial uses eksctl to setup Cloud Formation stacks that will provision the cloud resources required to stand up an EKS cluster.

## Instructions

### Prerequisites

#### Required Tools

* [AWS CLI](https://aws.amazon.com/cli/) [`aws`] is a tool that interacts with AWS.
* [eksctl](https://kubernetes.io/docs/reference/kubectl/) [`eksctl`] is the tool that can provision EKS cluster as well as supporting VPC network infrastructure.
* [Kubernetes client](https://kubernetes.io/docs/reference/kubectl/) [`kubectl`] a the tool that can interact with the Kubernetes cluster. This can be installed using `adsf` tool.
* [helm](https://helm.sh/) [`helm`] is a tool that can install Kubernetes applications that are packaged as helm charts.
* [POSIX Shell](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html) [`sh`] such as [bash] [`bash`](https://www.gnu.org/software/bash/) or [zsh](https://www.zsh.org/) [`zsh`] are used to run the commands. These come standard on Linux, and with macOS you can get the latest with `brew install bash zsh` if [Homebrew](https://brew.sh/) is installed.

#### Optional Tools

* [adsf](https://asdf-vm.com/) [`adsf`] is a tool that installs versions of popular tools like kubectl.
* [jq](https://jqlang.github.io/jq/) [`jq`] is a tool to query and print JSON data
* [GNU Grep](https://www.gnu.org/software/grep/) [`grep`] supports extracting string patterns using extended [Regex](https://wikipedia.org/wiki/Regular_expression) and [PCRE](https://wikipedia.org/wiki/Perl_Compatible_Regular_Expressions). This comes default on Linux distros, and for macOS it can be installed with `brew install grep` if [Homebrew](https://brew.sh/) is installed.

#### AWS Account Setup

Setup a [AWS account](https://aws.amazon.com/account/) and setup [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html). You can use the [free teir](https://aws.amazon.com/free/) account.

After setting up a profile, you can test it with the following: 

```bash
export AWS_PROFILE="<your-profile-goes-here>"
aws sts get-caller-identity
```

### Populate Environment Variables

Create an env.sh that will hold the environment variables needed for this project.

```bash
cat <<-'EOF' > env.sh
# variables used to create EKS
export AWS_PROFILE="my-aws-profile" # CHANGEME
export EKS_CLUSTER_NAME="my-unique-cluster-name" # CHANGEME
export EKS_REGION="us-west-2"
export EKS_VERSION="1.26"
# KUBECONFIG variable
export KUBECONFIG=$HOME/.kube/$EKS_REGION.$EKS_CLUSTER_NAME.yaml

# account id
export ACCOUNT_ID=$(aws sts get-caller-identity \
  --query "Account" \
  --output text
)

# aws-load-balancer-controller
export POLICY_NAME_ALBC="${EKS_CLUSTER_NAME}_AWSLoadBalancerControllerIAMPolicy"
export POLICY_ARN_ALBC="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME_ALBC"
export ROLE_NAME_ALBC="${EKS_CLUSTER_NAME}_AmazonEKSLoadBalancerControllerRole"

# ebs-csi-driver
export ROLE_NAME_ECSI="${EKS_CLUSTER_NAME}_EBS_CSI_DriverRole"
export ACCOUNT_ROLE_ARN_ECSI="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME_ECSI"
POLICY_NAME_ECSI="AmazonEBSCSIDriverPolicy" # preinstalled by AWS
export POLICY_ARN_ECSI="arn:aws:iam::aws:policy/service-role/$POLICY_NAME_ECSI"
EOF
```

### Helm Reposistories (optional)

If you would like to download all the Helm chart repositories in adavance you can run this:

```bash
# add AWS LB Controller (NLB/ALB) helm charts
helm repo add "eks" "https://aws.github.io/eks-charts"
# add Calico CNI helm charts
helm repo add "projectcalico" "https://docs.tigera.io/calico/charts"
# add Dgraph helm charts (demo application)
helm repo add "dgraph" "https://charts.dgraph.io"

# download charts
helm repo update
```

### Install Latest kubectl (optional)

You should install a Kubenretes CLI client `kubectl` that matches the GKE cluster that will be installed later.  If you have [asdf](https://asdf-vm.com/) command, you can use this to fetch the latest `kubectl` binary for your workstation. 

#### Fetch the latest kubectl using asdf command.  

The [asdf](https://asdf-vm.com/) command must be installed before using these steps.

```bash
# install kubectl plugin for asdf
asdf plugin-add kubectl \
  https://github.com/asdf-community/asdf-kubectl.git

# fetch latest kubectl 
asdf install kubectl latest
asdf global kubectl latest

# test results of latest kubectl 
kubectl version --client
```

Also setup the KUBECONFIG default directory:

```bash
mkdir -p $HOME/.kube
```

### Provision Cloud Resources


#### IAM Role, Security Groups, Network, and EKS

```bash
eksctl create cluster --version $EKS_VERSION --region $EKS_REGION --name $EKS_CLUSTER_NAME --nodes 3
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --region $EKS_REGION --approve
```

You can verify the OIDC provider with:

```bash
OIDC_ID=$(aws eks describe-cluster \
  --name $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text \
  | cut -d '/' -f 5
)

aws iam list-open-id-connect-providers | grep $OIDC_ID | cut -d '"' -f4 | cut -d '/' -f4
```


#### kubectl matching EKS 

```bash
# fetch exact version of Kubernetes server (Requires GNU Grep)
VER=$(kubectl version \
  | grep -oP '(?<=Server Version: v)(\d{1,2}\.){2}\d{1,2}'
)

# setup kubectl tool
asdf list kubectl | grep -q $VER || asdf install kubectl $VER
asdf global kubectl $VER
```

#### Verify 

```bash
kubectl get nodes
kubectl get all --all-namespaces
```

### Install Other EKS Addons

#### AWS Load Balancer Controller

```bash
#######################
# Download ALBC Policy
#######################################
VER="v2.5.2" # change if version changes
PREFIX="https://raw.githubusercontent.com"
HTTP_PATH="kubernetes-sigs/aws-load-balancer-controller/$VER/docs/install"
FILE_GOV="iam_policy_us-gov"
FILE_REG="iam_policy"

# Download the appropriate link
curl --remote-name --silent --location $PREFIX/$HTTP_PATH/$FILE_REG.json

#######################
# Upload Policy
#######################################
aws iam create-policy \
    --policy-name $POLICY_NAME_ALBC \
    --policy-document file://iam_policy.json

#######################
# Associate Service Account with the uploaded policy
#######################################
eksctl create iamserviceaccount \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --namespace "kube-system" \
  --name "aws-load-balancer-controller" \
  --role-name $ROLE_NAME_ALBC \
  --attach-policy-arn $POLICY_ARN_ALBC \
  --approve

#######################
# Install AWS load balancer controller add-on
#######################################
helm install \
  aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "kube-system" \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller  
```

The following commands are useful for verifying or truobleshooting the components

```bash
#######################
# Verify IAM role is installed
#######################################
aws iam get-role --role-name $ROLE_NAME_ALBC

#######################
# Verify service account metadata
#######################################
kubectl get serviceaccount "aws-load-balancer-controller" \
  --namespace "kube-system" \
  --output yaml

#######################
# Verify installed ALBC pods
#######################################
kubectl get all \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-load-balancer-controller"
```

#### AWS EBS CSI Controller

EKS 1.23+ no longer comes with a functional CSI driver, so this is absolutely required if you need persistent volumes.

**NOTE**: The EBS CSI driver can be installed with either EKS addon facility or the Helm chart.  The addon installs both the core EBS CSI driver, as well as containers supporting a snapshot capability. 


```bash
#######################
# AWS IAM role bound to a Kubernetes service account
#######################################
eksctl create iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --attach-policy-arn $POLICY_ARN_ECSI \
  --role-only \
  --role-name $ROLE_NAME_ECSI \
  --approve

#######################
# Install EBS CSI using EKS addon
#######################################
eksctl create addon \
  --name "aws-ebs-csi-driver" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION \
  --service-account-role-arn $ACCOUNT_ROLE_ARN_ECSI \
  --force

# Pause here until STATUS=ACTIVE
ACTIVE=""; while [[ -z "$ACTIVE" ]]; do
  if eksctl get addon \
       --name "aws-ebs-csi-driver" \
       --region $EKS_REGION \
       --cluster $EKS_CLUSTER_NAME \
    | tail -1 \
    | awk '{print $3}' \
    | grep -q "ACTIVE"
  then
    ACTIVE="1"
  fi
done

#######################
# Create storage class using EBS CSI w gp3
#######################################
cat <<EOF | kubectl apply --filename -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

#######################
# Set default sc to ebs-sc
#######################################
kubectl patch storageclass gp2 --patch \
 '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass ebs-sc --patch \
 '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

The following commands are useful for verifying or truobleshooting the components

```bash
#######################
# Verify IAM role is installed
#######################################
aws iam get-role --role-name $ROLE_NAME_ECSI

#######################
# Verify service account metadata
#######################################
kubectl get serviceaccount "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --output yaml

#######################
# Verify installed EBS CSI pods
#######################################
kubectl get pods \
  --namespace "kube-system" \
  --selector "app.kubernetes.io/name=aws-ebs-csi-driver"

#######################
# Verify default storage class
#######################################
kubectl get storageclass
```

#### Calico

```bash
#######################
# Install Calico
#######################################

# create ns for operator
kubectl create namespace tigera-operator

# deploy calico cni
helm install calico projectcalico/tigera-operator \
  --version v3.26.1 \
  --namespace tigera-operator \
  --set installation.kubernetesProvider=EKS

#######################
# Enable Pod IP annotation (important)
#######################################
cat << EOF > append.yaml
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF

# patch cluster role to allow updating annotations
kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append.yaml)

# enable pod annotation
kubectl set env daemonset aws-node \
  --namespace kube-system \
  ANNOTATE_POD_IP=true

# delete existing pod, so that they are refreshed with the annotation
kubectl delete pod \
  --selector app.kubernetes.io/name=calico-kube-controllers \
  --namespace calico-system
```

The following commands are useful for verifying or truobleshooting the components

```bash
#######################
# Verify Pod IP annotation support
#######################################
kubectl describe pod \
  --selector app.kubernetes.io/name=calico-kube-controllers \
  --namespace calico-system \
  | grep -o vpc.amazonaws.com/pod-ips.*$
```


#### Cleanup 

```bash
#######################
# Reset default non-functional storage class
#######################################
kubectl patch storageclass ebs-sc --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass gp2 --patch \
  '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

#######################
# Delete IAM roles
#######################################
eksctl delete iamserviceaccount \
  --name "aws-load-balancer-controller" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION

eksctl delete iamserviceaccount \
  --name "ebs-csi-controller-sa" \
  --namespace "kube-system" \
  --cluster $EKS_CLUSTER_NAME \
  --region $EKS_REGION

#######################
# Delete policy
#######################################
aws iam delete-policy --policy-arn "$POLICY_ARN_ALBC"

#######################
# EKS and client config
#######################################
eksctl delete cluster --region $EKS_REGION --name $EKS_CLUSTER_NAME
rm -f $KUBECONFIG
```

## Published Articles

* [Ultimate EKS Baseline Cluster](https://joachim8675309.medium.com/ultimate-eks-baseline-cluster-46593e75bb68)
* [Ultimate EKS Baseline Cluster: Part 1 - Provision EKS](https://dev.to/joachim8675309/ultimate-eks-baseline-cluster-part-1-provision-eks-17f)
* [Ultimate EKS Baseline Cluster: Part 2 - Storage](https://dev.to/joachim8675309/ultimate-eks-baseline-cluster-part-2-storage-3kpi)