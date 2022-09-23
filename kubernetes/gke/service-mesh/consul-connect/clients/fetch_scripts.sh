#!/usr/bin/env bash

USER="darkn3rd"
GIST_ID="089d18ac58951709a98ac6a617f26bea"
VERS="4ef6484097398885187b52c731009190deb75b23"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
echo "Fetching Scripts from $URL"
curl -s $URL | bash -s --
