# Ingress Tests

These are used to test basic ingress controller configuration and usage. After testing this with NGINX+, these should be tried with open source NGINX to show what could work and not work, as far as features.

1. Basic HTTP Ingress
   - ingress
   - virtualserver
2. ExternalDNS integration
   - ingress
   - virtualserver
3. CertManager + ExternalDNS integration
   - ingress
   - virtualserver
4. gRPC + CertManager + ExternalDNS
   - ingress
   - virtualserver

Blog Notes:

* If oss nginx-ic works, then this should be used
* document basic ingress for gRPC and HTTP mixed traffic.
* document virtualserver for mixed gRPC and HTTP traffic.
* particular routes should be supported, admin and mutation routes should be denied.
