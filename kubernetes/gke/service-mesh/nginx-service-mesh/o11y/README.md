# NSM Observability

These contain Kubernetes manifests that are used to install the following components:

* [Grafana](https://grafana.com/) - metric visualization dashboards
* [Jaeger](https://www.jaegertracing.io/) - popular distributed tracing platform
* [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)-  vendor-agnostic reference implementation of a collector that is used to receive, process and export telemetry data.
* [Prometheus](https://prometheus.io/) - metrics platform

This solution will download applicable Kubernetes manifests and convert helm charts using the raw helm chart.  The raw helm chart is essentially a raw Kubernetes manifests repackaged as Helm chart values.  This allows you to add automation to otherwise static Kubernetes manifests.  The Helmfile tool will allow you to use several Helm charts together as a single package, and inject common values across all the helm charts.  Thus as Helm cuatomates Kubernetes manifests with templating, Helmfile automates Helm charts with templating.

The goal of this is to have several manifests installed as a single package, so that it is easier to manage,  such as deleting these in the future.  The alternative is to patch or delete all of the manifests individually, rather than as a single using.

## Instructions

You can fetch the manifests and install the manifests as Helm charts with these commands.

```bash
./fetch_manifests.sh
helmfile apply
```

To uninstall them with helmfile, you can run:

```bash
helmfile delete
```

If you want to uninstall using just helm, you can do it with:


```bash
helm delete --namespace nsm-monitoring jaeger
helm delete --namespace nsm-monitoring prometheus
helm delete --namespace nsm-monitoring otel-collector
helm delete --namespace nsm-monitoring grafana
```


```
