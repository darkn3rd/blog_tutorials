# Clients

These set of scripts build a docker image with some data and a client script `load_data.py` that uses pydgraph module.  This script will load the Getting Started data using gRPC.

```bash
#######################
# Download Setup Environment
##########################################
USER="darkn3rd"
GIST_ID="414d9525ca4f3be0a58799ec2a10f6b3"
VERS="0247468063740eb969a84c6d82575202c5997aa7"
FILE="setup_pydgraph_gcp.sh"
URL=https://gist.githubusercontent.com/$USER/$GIST_ID/raw/$VERS/$FILE
curl -s $URL | bash -s --

#######################
# Load Data with pydgraph-client
##########################################
pushd examples/pydgraph
make build

docker run -t pydgraph-client:latest \
  python3 load_data.py \
    --alpha grpc.$DNS_DOMAIN:443 \
    --files ./sw.nquads.rdf \
    --schema ./sw.schema
popd
```

You can review the results afterward with Ratel.
