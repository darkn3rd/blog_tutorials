
# Consul Getting Started

* https://www.consul.io/docs/k8s/installation/install


## CLI

```bash
# https://www.consul.io/docs/k8s/installation/install-cli
if [[ "$(uname -s)" == "Linux" ]]; then
  # UBUNTU
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install consul-k8s
  # RHEL
  # sudo yum install -y yum-utils
  # sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  # sudo yum -y install consul-k8s
elif  [[ "$(uname -s)" == "Darwin" ]]; then
  brew tap hashicorp/tap
  brew install hashicorp/tap/consul-k8s
fi
```

## HELM

```bash
# https://www.consul.io/docs/k8s/installation/install
helm repo add hashicorp https://helm.releases.hashicorp.com
cat << EOF > config.yaml
global:
  name: consul
connectInject:
  enabled: true
controller:
  enabled: true
EOF
helm install consul hashicorp/consul --create-namespace --namespace consul --values config.yaml
