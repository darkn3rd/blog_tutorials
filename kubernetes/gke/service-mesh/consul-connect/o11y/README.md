
# Grafana

```bash
kubectl port-forward --namespace grafana svc/grafana 3000:3000
```

# Prometheus

```bash
kubectl port-forward --namespace prometheus deploy/prometheus-server 9090:9090
```

# Consul UI

```bash
kubectl port-forward consul-server-0 --namespace consul 8500:8500
```


# References

* [Layer 7 Observability with Prometheus, Grafana, and Kubernetes](https://learn.hashicorp.com/tutorials/consul/kubernetes-layer7-observability?in=consul/kubernetes-features)
* [Service Mesh Observability: UI Visualization](https://www.consul.io/docs/connect/observability/ui-visualization)
* https://github.com/hashicorp/learn-consul-kubernetes
