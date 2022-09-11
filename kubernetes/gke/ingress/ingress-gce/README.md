# GCE Ingress with CertManager and ExternalDNS

This workshop tutoral demonstrates how to support a secure web service using certifictes on GKE (Google Kubernetes Engine).
This will run through the following technologies:

* Google Cloud solutions
  * GKE (Google Kubernetes Engine)
  * Cloud DNS
  * GSA (Google Serivce Account)
  * [Workgroup Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
* Kubernetes solutions
  * [ExternalDNS](https://github.com/kubernetes-sigs/external-dns)
  * [CertManager](https://cert-manager.io/)
  * [GKE Ingress for HTTP(S) Load Balancing](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
    * [ingress-gce](https://github.com/kubernetes/ingress-gce)

## Requirements

* Accounts
  * Registered Domain and point it to Google Cloud DNS name server
  * Google Cloud billing account setup
* Tools
  * Google Cloud SDK (`gloud`)
  * Kubernetes Client (`kubectl`)
  * Helm (`helm`)
    * Helm Diff Plugin
  * Helmfile
* Optional
  * GNU Bash (`bash`), GNU Sed (`sed`), GNU Grep (`grep`) - scripts tested with these tools
  * Homebrew (`brew`) on macOS to download and install packages as needed
