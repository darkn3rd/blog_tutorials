# EKS 3: Ingress Nginx

This is supporting code to creating the following:

* Provisioning EKS with `eksctl`
  * Notes on BYOC (*bring-your-own-cluster*) to implement your own cluster
* Adding `external-dns` and `ingress-nginx` addons
  * Notes for Route53 and AWS Certificate Manager setup
* Deploying Application that uses the ingress with DNS and TLS

## Sections

* [Part 0: Provision EKS](part0_provision/README.md)
* [Part 1: Kubernetes Addons](part1_addons/README.md)
* [Part 2: Deploy Application](part2_app/README.md)
