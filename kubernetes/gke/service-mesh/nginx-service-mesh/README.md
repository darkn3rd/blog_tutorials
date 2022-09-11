 # NGINX Service Mesh

 This tutorial will be divided into two parts, due to necessary complexity involved in both using the service mesh itself for east-west traffic and the endpoint ingress for NGINX ingress controller with support for DNS and certificates.

 * Part 1
   * Cloud Resources
     * Google Kubernetes Engine
     * Google Contianer Registry
   * Kubernetes Resources
     * o11y (observability)
       * Jaeger
       * OpenTelemetry Collector
       * Prometheus
       * Grafana
     * nsm (NGINX service mesh)
 * Part 2
   * Cloud Resources
     * Google Cloud DNS zone
   * Kubenetes Components
     * external-dns
     * cert-manager
     * kubernetes-ingress (NGINX ingress controller)
