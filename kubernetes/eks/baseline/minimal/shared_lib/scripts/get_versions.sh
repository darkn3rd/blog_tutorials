#!/usr/bin/env bash
set -euo pipefail

printf "aws: %s\nkubectl: %s\nhelm: %s\neksctl: %s\nterraform: %s\n" \
  "$(aws --version 2>&1 | awk -F'[/ ]' '{print $2}')" \
  "$(kubectl version --client | awk '/Client Version:/ {print $3}')" \
  "$(helm version --short | cut -d+ -f1)" \
  "$(eksctl version | cut -d- -f1)" \
  "$(terraform version | awk '/Terraform/{print $2}')"

