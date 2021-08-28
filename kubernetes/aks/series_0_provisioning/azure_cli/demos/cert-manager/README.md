# CertManager Demos

These solutions will use K8S `ingress` resource, so an ingress controller must be installed.  

When `cert-manager` and corresponding issuers are installed and functional, certificates will be created automatically.  For `cert-manager` to work, it must have access to Azure DNS zone to validate the rights to the domain name, which will allow it to issue publically trusted X.509 certificates for the web service.  Otherwise, private untrusted certificates will be issued.

The required add-ons for this service are the following:

* External DNS (external-dns)
* Ingress Controller, such as ingress-nginx

For publically trusted certificates, where you do not need to add an exception to access the website through HTTPS, you need to point your domain from your domain provider to Azure DNS managed zone.  This way any domain name used from the Internet will be pubically accessible.

## Environment Variables

The following environment variables need to be set before running these scripts:

* `AZ_DNS_DOMAIN` such as `example.com` or `example.internal`
* `ACME_ISSUER` to point to the proper issuer
