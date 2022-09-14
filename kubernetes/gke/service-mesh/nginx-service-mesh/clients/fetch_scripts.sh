#!/usr/bin/env bash
USER="darkn3rd"
GIST_ID="414d9525ca4f3be0a58799ec2a10f6b3"
VERS="0247468063740eb969a84c6d82575202c5997aa7"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
curl -s $URL | bash -s --
