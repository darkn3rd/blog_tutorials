

```bash
# https://learn.hashicorp.com/tutorials/consul/kubernetes-layer7-observability
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts \
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

git clone https://github.com/hashicorp/learn-consul-kubernetes.git
cd learn-consul-kubernetes/layer7-observability
git checkout tags/v0.0.15
```
