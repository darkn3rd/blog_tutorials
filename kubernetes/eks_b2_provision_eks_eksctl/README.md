# Provision EKS Cluster on existing VPC Infrastructure

This will cover provisioning on an existing VPC.

The dynamic part relies on the VPC module rendering a state, so if you already have VPC, then you'll need to supply a list of subnet-ids, or import vpc into the state file.

**TODO**: Add Part3 that uses `aws_subnet_ids` to dynamically build a map (ref: [aws_subnet_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids))

## Tools Needed

* Terraform
* AWS CLI (tested with v1)
  * configured with profile that allows acces to create resources
* eksctl

## Two Parts

There are two parts

* [Part 1: Static Config](part1_static_config/README.md) - static config script that requies editing values
* [Part 2: Template Config](part2_temlpate_config/README.md) - dynamic config generated using Terraform
