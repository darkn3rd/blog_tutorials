#!/usr/bin/env bash

# JQ examples
# Background: This is dicard pile for queries previously used in this article
# using jq. While `jq` is more ubiqituous across many platforms for the shell,
# it will often require download/install of `jq` which is yet another tool to
# install.
#
# The preferred method, though less optimal, is to use what is natively
# supported.
#
# For most close tools (az, aws, gcloud) that use python wrapper scripts,
# JMESPath is the preferred method.
#
# For Kubernetes (kubectl), JSONPath is used.
#
# This area keeps jq queries I figured out, and want to keep around for future
# content, such as how to master JSON queries in all threee platforms.


az network dns zone list | jq ".[] | select(.name == \"$AZ_DNS_DOMAIN\")"

export AZ_DNS_SCOPE=$(
  az network dns zone list |
   jq -r ".[] | select(.name == \"$AZ_DNS_DOMAIN\").id"
)
