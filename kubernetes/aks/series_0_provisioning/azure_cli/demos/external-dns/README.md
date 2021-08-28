# External DNS demos

These solutions will use K8S `service` resource of type `LoadBalancer`.  

When `external-dns` is installed and functional, DNS records will be updated on Azure DNS.

## Environment Variables

The following environment variables need to be set before running these scripts:

* `AZ_DNS_DOMAIN` such as `example.com` or `example.internal`
