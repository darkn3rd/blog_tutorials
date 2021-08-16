#!/usr/bin/env bash

TF_VARS=${TF_VARS:-"$(dirname $0)/../terraform.tfvars"}

cat <<-EOF >> $TF_VARS
resource_group_name = "aks-basic-test"
location            = "westus2"
cluster_name        = "basic-test"
dns_prefix          = "basic-test"
EOF
