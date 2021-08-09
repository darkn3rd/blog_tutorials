# AKS 5 - Kubernetes Endpoing

This area of projects explores configuring `ingress` and `service` resources for inbound gRPC (HTTP/2) and HTTP traffic with automation for issuing X.509 certificates (`cert-manager`), DNS records upserts (`external-dns`), and an ingress controller.

This will cover the following topics:

* `external-dns` (Azure DNS) for `service` (`LoadBalancer`) and `ingress` resources
* `cert-manager` (Let's Encrypt) with `DNS01` validation (Azure DNS) for ingress resources
* ingress controller (`ingress-nginx`) for mixed gRPC (HTTP/2) and HTTP traffic

## Sections

* [Part 1: external-dns](./1_externaldns/README.md) - automating upserts on Azure DNS zone for the `service` resource.
* [Part 2: HTTP ingress (ingress-nginx)](./2_ingress_nginx/README.md) - adding an ingress controller to route L7 (HTTP) traffic to backend services
* [Part 2: cert-manager](./3_cert_manager/README.md) - automatically issuing certificates for an ingress with `DNS01` validation to an Azure DNS zone.
* [Part 3: gRPC ingress (ingress-nginx)](./4_ingress_nginx_grpc/README.md) - using ingress controller to route mixed gRPC (HTTP/2) and HTTP.  
