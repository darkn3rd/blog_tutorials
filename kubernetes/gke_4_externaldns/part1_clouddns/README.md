# Part 1: Setup

For this phase you need to should have the following:

* Prerequisite Tools: `gcloud`, `kubectl`, and `helm` command line tools.
* Cloud DNS configured with a zone for a registerd doman or sub-domain
* GKE cluster with CloudDNS API scope configured as current KUBECONFIG context


## Step 1: Check Cloud DNS

```bash
ZONE_NAME="<your_zone_name_goes_here>" # acme-test
./check_clouddns.sh
```

## Step 2: Setup Cluster

* [Provision using Google Cloud SDK](../../gke_1_provision_cloudsdk/README.md)
* [Provision using Terraform](../../gke_2_provision_terraform/README.md)


## Step 3: Install External DNS

```bash
MY_DOMAIN="<set-your-domain-name-here>" # example: test.acme.com
./install_external_dns.sh $MY_DOMAIN
```
