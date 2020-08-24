# Provision VPC Cluster with EKS Cluster Tags

This covers the base network infrastructure required for a functional EKS infrastructure.  This is provisioned with Terraform using a seperate module.

This will setup:
* VPC
* Private Subnets (tagged for EKS)
* Public Subnets (tagged for EKS)
* Route Tables
* Gateway

## Tools Needed

* Terraform
* AWS CLI (tested with v1)
  * configured with profile that allows acces to create resources

## Files Created

```bash
mkdir vpc
touch vpc/{locals,main,output,variables,versions}.tf
touch {main,provider}.tf terraform.tfvars
```
