# Blog Tutorials

These are code related to tutorials created.

## Die Blogs ( Τα ιστολόγια / Блогҳо / ብሎጎቹ )

### General

* Docker
    * Docker Command vs Ansible - https://medium.com/@Joachim8675309/docker-using-shell-or-docker-compose-4ab8ea8ae801
    * Docker Command vs. Docker Compose - https://medium.com/@Joachim8675309/docker-using-shell-or-ansible-7cdceb646d3
* Virtual Box
    * Windows
         * Windows 8.1 - https://medium.com/@Joachim8675309/virtualbox-and-friends-on-windows-8-1-3c691460698f
    * macOS (Mac OS X)
         * macOS 10.13.5 - https://medium.com/@Joachim8675309/virtualbox-and-friends-on-macos-fd0b78c71a32
    * Linux
         * Fedora 28 - https://medium.com/@Joachim8675309/vagrant-and-friends-on-fedora-28-37b8cbc47e47
* Vagrant
    * Provisioners
         * Shell (`shell`) - https://medium.com/@Joachim8675309/vagrant-provisioning-e4c9fd57968d
         * Ansible (`ansible_local`) - https://medium.com/@Joachim8675309/vagrant-provisioning-with-ansible-6dba6bca6290
         * Docker (`docker`) - https://medium.com/@Joachim8675309/vagrant-provisioning-with-docker-3621df12092a
         * Chef (`chef_zero`) - https://medium.com/@Joachim8675309/vagrant-provisioning-with-chef-90a2bf724f
         * Puppet (`puppet`) - https://medium.com/@Joachim8675309/vagrant-provisioning-with-puppet-553a59f0c48e
         * Salt Stack (`salt`) - https://medium.com/@Joachim8675309/vagrant-provisioning-with-saltstack-50dab12ce6c7
* Kitchen (Test Kitchen)
    * Chef, Busser/ServerSpec, InSpec
         * https://medium.com/@Joachim8675309/testkitchen-with-chef-and-serverspec-2ac0cd938e5
    * Ansible, Busser/TestInfra, Shell/TestInfra
         * https://medium.com/@Joachim8675309/testkitchen-with-ansible-and-testinfra-e3fc4320ced
* Chef
    * Overview: https://medium.com/@Joachim8675309/testing-on-the-chef-platform-overview-8e29b4f050ca
    * Integration w/ InSpec: https://medium.com/@Joachim8675309/testing-chef-cookbooks-with-inspec-c18ec1119c94
* Salt Stack
    * developing formulas (`vagrant`) - https://joachim8675309.medium.com/building-gke-with-terraform-869df1cd3f41
    * using external formulas (`vagrant`) - https://joachim8675309.medium.com/salt-devkit-with-external-formulas-9e38d8b90cd7

### Language Platforms

* Getting Compilers - https://joachim8675309.medium.com/getting-compilers-d4819d95942a
* Python
    * Manage Pythons (`pyenv`) - https://joachim8675309.medium.com/installing-pythons-with-pyenv-54cca2196cd3
    * Mange Virtualenvs (`virtualenv)` - https://joachim8675309.medium.com/getting-compilers-d4819d95942a
* Ruby
    * Manage Rubies (`rvm`) - https://joachim8675309.medium.com/a-tale-of-two-rubies-part-i-34e5658c5bfc
    * Manage Rubies (`rbenv`) - https://joachim8675309.medium.com/a-tale-of-two-rubies-part-ii-5c3904dc4b3b
    * Manage Gemsets (`rvm`, `rbenv`) - https://joachim8675309.medium.com/the-great-gemset-debate-a8007fc29644
    * Integrating ChefDK integrated ruby (`rvm`, `rbenv`) - https://joachim8675309.medium.com/three-rubies-and-a-chefdk-74dc8c9149a7
* NodeJS (`nvm`) - https://joachim8675309.medium.com/installing-node-js-with-nvm-4dc469c977d9


### Continuous Integration

* Jenkins
  * Jenkins DevKit on Win10 Home (`docker-machine`)- https://medium.com/swlh/jenkins-devkit-windows-home-231aef40c415
  * Jenkins DevKit: Automating Jenkins 1 (`docker-compose`) - https://joachim8675309.medium.com/jenkins-devkit-automating-jenkins-42b970550a0b
  * Jenkins DevKit: Automating Jenkins 2 (JobDSL, CasC, Pipelines) - https://joachim8675309.medium.com/jenkins-devkit-automating-jenkins-2-46e8b276d787
  * Jenkins CI Pipeline with Python - https://joachim8675309.medium.com/jenkins-ci-pipeline-with-python-8bf1a0234ec3
  * Jenkins CI Pipeline with Ruby - https://joachim8675309.medium.com/jenkins-ci-pipeline-with-ruby-62017469c7c9

### Continuous Delivery

* Spinnaker with Amazon ECR - https://joachim8675309.medium.com/spinnaker-with-amazon-ecr-5236c15808e6

### Cloud Native Infrastructure

* Azure
  * Azure VM + PublicIP (`terraform`) - https://joachim8675309.medium.com/azure-linux-vm-with-infra-99af44039253
  * Azure VM + DNS (`terraform`) - https://joachim8675309.medium.com/azure-linux-vm-with-dns-e54076bab296
* AWS
  * AWS Infrastructure 1 (`terraform`) - https://joachim8675309.medium.com/building-aws-infra-with-terraform-96387481b9d7
  * AWS Infrastructure 2 (`terraform`) - https://joachim8675309.medium.com/building-aws-infra-with-terraform-2-ca60146666f8

* K8S or Kubernetes
  * General
      * Helmfile (`helmfile`) - https://joachim8675309.medium.com/devops-tools-introducing-helmfile-f7c0197f3aea
      * Helm3 + Helm2 on macOS (`helm`) - https://joachim8675309.medium.com/install-helm3-helm2-on-macos-d65f61509799
  * AKS
      * Provisioning
          * Azure CLI
              * Basic AKS (`az`) - https://joachim8675309.medium.com/azure-kubernetes-service-b89cc52b7f02
              * PodIdentity preview w/ cert-manager + external-dns (`az`) - https://joachim8675309.medium.com/aks-with-aad-pod-identity-7c2cbf906eb9
              * PodSubnet preview w/ Azure CNI plugin (`az`) - https://joachim8675309.medium.com/aks-with-azure-cni-ae36712b1e8c
          * Terraform
              * Basic AKS (`terraform`) - https://joachim8675309.medium.com/building-aks-with-terraform-662a61acb59c
      * External DNS + Security
          * ExternalDNS/AzureDNS 1 (kubelet identity) - https://joachim8675309.medium.com/externaldns-with-aks-azure-dns-941a1804dc88
          * ExternalDNS/AzureDNS 2 (static credentials)- https://joachim8675309.medium.com/externaldns-w-aks-azure-dns-2-316142fa006f
      * Managing Endpoints: service and ingress
          * external-dns - https://joachim8675309.medium.com/extending-aks-with-external-dns-3da2703b9d52
          * ingress-nginx - https://joachim8675309.medium.com/aks-with-ingress-nginx-7c51da500f69
          * cert-manager - https://joachim8675309.medium.com/aks-with-cert-manager-f24786e87b20
          * ingress-nginx w/ gRPC - https://joachim8675309.medium.com/aks-with-grpc-and-ingress-nginx-32481a792a1
      * Service Meshes and Network Policies
          * Container Registry w/ ACR - https://joachim8675309.medium.com/aks-with-azure-container-registry-b7ff8a45a8a
          * Network Policies w/ Calico - https://joachim8675309.medium.com/aks-with-calico-network-policies-8cdfa996e6bb
          * Linkerd service mesh - https://joachim8675309.medium.com/linkerd-service-mesh-on-aks-a75d60ef4f5a
          * Istio service mesh - https://joachim8675309.medium.com/istio-service-mesh-on-aks-1b6ed16f6890
  * EKS
      * VPC + EKS (`eksctl`) - https://joachim8675309.medium.com/building-eks-with-eksctl-799eeb3b0efd
      * VPC for future EKS (`terraform`) - https://joachim8675309.medium.com/create-an-amazon-vpc-for-eks-597481514bcc
      * EKS using existing VPC (`terraform` + `eksctl`) - https://joachim8675309.medium.com/create-eks-with-an-existing-vpc-8e31d95ccc5b
      * Terraform with K8S Provider - https://joachim8675309.medium.com/deploy-kubernetes-apps-w-terraform-266f3e8028d2
      * Nginx Ingress - https://joachim8675309.medium.com/adding-ingress-with-amazon-eks-6c4379803b2
      * ALB Ingress - https://joachim8675309.medium.com/alb-ingress-with-amazon-eks-3d84cf822c85
      * External DNS + Security
        * ExternalDNS/Route53 1 (EC2 IAM Role)- https://joachim8675309.medium.com/externaldns-with-eks-and-route53-90aa23fa3aba
        * ExternalDNS/Route53 2 (static credentials) - https://joachim8675309.medium.com/externaldns-w-eks-and-route53-pt2-e94c705f62ae
        * ExternalDNS/Route53 3 (IAM Role to Service Account) - https://joachim8675309.medium.com/externaldns-w-eks-and-route53-pt3-9a71ab08c6bb
  * GKE
      * Early Articles
        * GKE with Gcloud SDK (`gcloud`) - https://medium.com/swlh/building-a-gke-with-cloud-sdk-99fee12bf0a6
        * GKE with Terraform (`terraform`) - https://joachim8675309.medium.com/building-gke-with-terraform-869df1cd3f41
        * Endpoint with Service or Ingress (`kubectl`) - https://medium.com/google-cloud/deploying-service-or-ingress-on-gke-59a49b134e3b
        * Managed SSL (`kubectl`) - https://joachim8675309.medium.com/securing-gke-with-managed-ssl-4261ce2d5228
        * ExternalDNS (`helm`) - https://medium.com/swlh/extending-gke-with-externaldns-d02c09157793
        * Terraform with K8S Provider - https://joachim8675309.medium.com/deploy-kubernetes-apps-with-terraform-5b74e5891958
        * Terraform with Helm Provider - https://medium.com/swlh/deploying-helm-charts-w-terraform-58bd3a690e55
      * Continuous Integration
        * TeamCity Server (`gcloud`) - https://joachim8675309.medium.com/teamcity-on-google-cloud-b6d61eb0902d
      * External DNS + Security
        * ExternalDNS/CloudDNS 1 (worker node GSA) -https://joachim8675309.medium.com/externaldns-with-gke-cloud-dns-38a174fdced7
        * ExternalDNS/CloudDNS 2 (static credentials): https://joachim8675309.medium.com/externaldns-w-gke-cloud-dns-2-1226a00d01c0
      * Ingress Controller (north-south traffic)
        * NGINX Kubernetes Ingress Controller w gRPC - https://faun.pub/extending-gke-with-nginx-ic-2ae86a96de18
        * ingress-nginx w gRPC - https://joachim8675309.medium.com/gke-with-grpc-and-ingress-nginx-644730915677
        * gce-ingress w cert-manager - https://joachim8675309.medium.com/gke-with-certmanager-9bc00b086b73
      * Service Mesh (east-west traffic)
        * Consul Service Mesh - https://joachim8675309.medium.com/gke-with-consul-service-mesh-36598242d278
        * NGINX Service Mesh + NGINX Kubernetes Ingress Controller - https://joachim8675309.medium.com/gke-with-nginx-service-mesh-2-57bb2e6f823a
        * NGINX Service Mesh - https://joachim8675309.medium.com/gke-with-nginx-service-mesh-8b1073af07bf

* O11Y or Observability (Visualization, Alerting, Metrics, Logs, Traces)
    * Logs
        * Log Shipping: FileBeat (`docker-compose`) - https://joachim8675309.medium.com/devops-journey-log-shipping-a2cbc8e20206

* Security
    * Vault
        * AppRole (`docker-compose`) - https://joachim8675309.medium.com/hashicorp-vault-with-approle-auth-724178503903


## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
