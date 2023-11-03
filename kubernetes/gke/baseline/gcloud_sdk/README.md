# Ultimate Baseline GKE (gcloud sdk)

This is part of a series to setup a secure baseline Kubernetes cluster with GKE.

## Instructions

### Prerequisites

#### Required Tools

* [Google Cloud SDK](https://cloud.google.com/sdk) [`gcloud` command] to interact with Google Cloud
* [Kubernetes client](https://kubernetes.io/docs/reference/kubectl/) [`kubectl`] a the tool that can interact with the Kubernetes cluster. This can be installed using `adsf` tool.
* [helm](https://helm.sh/) [`helm`] is a tool that can install Kubernetes applications that are packaged as helm charts.
* [POSIX Shell](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html) [`sh`] such as [bash] [`bash`](https://www.gnu.org/software/bash/) or [zsh](https://www.zsh.org/) [`zsh`] are used to run the commands. These come standard on Linux, and with macOS you can get the latest with `brew install bash zsh` if [Homebrew](https://brew.sh/) is installed.

#### Optional Tools

* [adsf](https://asdf-vm.com/) [`adsf`] is a tool that installs versions of popular tools like kubectl.
* [jq](https://jqlang.github.io/jq/) [`jq`] is a tool to query and print JSON data
* [GNU Grep](https://www.gnu.org/software/grep/) [`grep`] supports extracting string patterns using extended [Regex](https://wikipedia.org/wiki/Regular_expression) and [PCRE](https://wikipedia.org/wiki/Perl_Compatible_Regular_Expressions). This comes default on Linux distros, and for macOS it can be installed with `brew install grep` if [Homebrew](https://brew.sh/) is installed.

#### Google Project Setup

Setup a Google Cloud account and setup [Google Cloud SDK](https://cloud.google.com/sdk/docs/install-sdk). You can get a [free trial](https://cloud.google.com/free) account with [$300 in free credits](https://cloud.google.com/free/docs/free-cloud-features#free-trial).

### Populate Environment Variables

Create an env.sh that will hold the environment variables needed for this project.

```bash
cat <<-'EOF' > env.sh
# global var
export GKE_PROJECT_ID="base-gke"

# network vars
export GKE_NETWORK_NAME="base-main"
export GKE_SUBNET_NAME="base-private"
export GKE_ROUTER_NAME="base-router"
export GKE_NAT_NAME="base-nat"

# principal vars
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

# gke vars
export GKE_CLUSTER_NAME="base-gke"
export GKE_REGION="us-central1"
export GKE_MACHINE_TYPE="e2-standard-2"

# kubectl client vars
export USE_GKE_GCLOUD_AUTH_PLUGIN="True"
export KUBECONFIG=~/.kube/gcp/$GKE_REGION-$GKE_CLUSTER_NAME.yaml

# gke
export GKE_PROJECT_ID="base-gke"
export GKE_CLUSTER_NAME="base"
export GKE_REGION="us-central1"
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"
export KUBECONFIG=~/.kube/gcp/$GKE_REGION-$GKE_CLUSTER_NAME.yaml

# other
export CLOUD_BILLING_ACCOUNT="<my-cloud-billing-account>" # <--CHANGEME
EOF
```

### Setup Projects

If you are starting from scratch or which to use a new project for this, you can run through these steps:

```bash
# create new project
gcloud projects create $GKE_PROJECT_ID

# set up billing to the GKE project
gcloud beta billing projects link $GKE_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT

# authorize APIs for GKE project
gcloud config set project $GKE_PROJECT_ID
gcloud services enable "compute.googleapis.com"
gcloud services enable "container.googleapis.com"
```

A script has been provided to do the steps above, which you can use with:

```bash
source env.sh
./scripts/create_projects.sh
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


#### Google Service Account


```bash
#######################
# list of minimal required roles
#######################################
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

#######################
# create google service account principal
#######################################
gcloud iam service-accounts create $GKE_SA_NAME \
  --display-name $GKE_SA_NAME --project $GKE_PROJECT_ID

#######################
# assign google service account to roles in GKE project
#######################################
for ROLE in ${ROLES[*]}; do
  gcloud projects add-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done
```

#### Networks

```bash
#######################
# create VPC for target region
#######################################
gcloud compute networks create $GKE_NETWORK_NAME \
  --subnet-mode=custom \
  --mtu=1460 \
  --bgp-routing-mode=regional

#######################
# create subnet (spanning all availability zones w/i region)
#######################################
gcloud compute networks subnets create $GKE_SUBNET_NAME \
  --network=$GKE_NETWORK_NAME \
  --range=10.10.0.0/24 \
  --region=$GKE_REGION \
  --enable-private-ip-google-access

#######################
# add support for outbound traffic
#######################################
gcloud compute routers create $GKE_ROUTER_NAME \
  --network=$GKE_NETWORK_NAME \
  --region=$GKE_REGION

gcloud compute routers nats create $GKE_NAT_NAME \
  --router=$GKE_ROUTER_NAME \
  --region=$GKE_REGION \
  --nat-custom-subnet-ip-ranges=$GKE_SUBNET_NAME \
  --auto-allocate-nat-external-ips
```

#### Google Kubernetes Environment

```bash
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --machine-type $GKE_MACHINE_TYPE \
  --enable-ip-alias \
  --enable-network-policy \
  --enable-private-nodes \
  --no-enable-master-authorized-networks \
  --master-ipv4-cidr 172.16.0.32/28 \
  --network $GKE_NETWORK_NAME \
  --subnetwork $GKE_SUBNET_NAME \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"
```

#### kubectl matching GKE 


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

#### Cleanup 

```bash
#######################
# GKE and client config
#######################################
gcloud container clusters delete $GKE_CLUSTER_NAME
rm -f $KUBECONFIG

#######################
# network infra
#######################################
gcloud compute routers nats delete $GKE_NAT_NAME --router $GKE_ROUTER_NAME
gcloud compute routers delete $GKE_ROUTER_NAME
gcloud compute networks subnets delete $GKE_SUBNET_NAME
gcloud compute networks delete $GKE_NETWORK_NAME

#######################
# list of roles configured earlier
#######################################
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

#######################
# remove service account from roles
#######################################
for ROLE in ${ROLES[*]}; do
  gcloud projects remove-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done
```

## Published Articles

* [Ultimate Baseline GKE cluster](https://medium.com/@joachim8675309/ultimate-baseline-gke-cluster-261c1b5544be)
* [Ultimate Baseline GKE cluster, Pt 2](https://medium.com/@joachim8675309/ultimate-baseline-gke-cluster-pt-2-b7c123290542)
