#!/usr/bin/env bash

USER="darkn3rd"
GIST_ID="089d18ac58951709a98ac6a617f26bea"
VERS="456ebf0db327ab2c278f29487431dabc0f2e5947"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
echo "Fetching Scripts from $URL"
curl -s $URL | bash -s --
