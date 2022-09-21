#!/usr/bin/env bash

USER="darkn3rd"
GIST_ID="089d18ac58951709a98ac6a617f26bea"
VERS="68bd5356561dd373ba13542fee4f978d8aace872"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
echo "Fetching Scripts from $URL"
curl -s $URL | bash -s --
