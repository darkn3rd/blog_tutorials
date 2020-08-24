# Provision EKS Cluster on existing VPC Infrastructure

This will cover provisioning on an existing VPC.

The dynamic part relies on the VPC module rendering a state, so if you already have VPC, then you'll need to supply a list of subnet-ids, or import vpc into the state file.

## Tools Needed

* Terraform
* AWS CLI (tested with v1)
  * configured with profile that allows acces to create resources
* eksctl

## Two Parts

There are two parts

* [Part 1: Static Config](part1_static_config/README.md) - static config script that requies editing values
* [Part 2: Template Config](part2_temlpate_config/README.md) - dynamic config generated using Terraform (requires TF state for VPC)
* [Part 3: Template Config v3](part2_temlpate_config/README.md) - dynamic config generated using Terraform (requires passing vpc_id)
