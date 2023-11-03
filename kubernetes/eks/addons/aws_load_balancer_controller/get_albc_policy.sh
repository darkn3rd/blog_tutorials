#!/usr/bin/env bash
VER="v2.4.7" # change if version changes
HTTP_PREFIX="https://raw.githubusercontent.com"
HTTP_PATH="kubernetes-sigs/aws-load-balancer-controller/$VER/docs/install"
FILE_GOV="iam_policy_us-gov"
FILE_REG="iam_policy"

# Download the appropriate link
curl --remote-name --silent --location ${HTTP_PREFIX}/${HTTP_PATH}/${FILE_REG}.json
