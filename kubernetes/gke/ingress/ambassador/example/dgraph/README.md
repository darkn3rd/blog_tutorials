# Dgraph

Dgraph is a highly performant distributed graph database. The following ports are used for externals communication with Dgraph Alpha

* port `8080`: http/1.1 for GraphQL or DQL
* Port `9080`: gRPC (http/2) for DQL

## Install

### Installation with Emissary-Ingress CRDs

Setup environment variables as needed:

```bash
export DGRAPH_HOSTNAME_HTTP="dgraph.local"
export DGRAPH_RELEASE_NAME="dg"
export DGRAPH_ALLOW_LIST="0.0.0.0/0"

# Install Dgraph 
./dgraph_install.sh

# Install Dgraph using Emissary-Ingress CRDs
./dgraph_emissary_ingress.sh
```

### Installation with classic legacy ingress API

Setup environment variables as needed:

```bash
export DGRAPH_HOSTNAME_HTTP="dgraph.local"
export DGRAPH_RELEASE_NAME="dg"
export DGRAPH_ALLOW_LIST="0.0.0.0/0"

# Install Dgraph 
./dgraph/dgraph_install.sh

# Install Dgraph using Emissary-Ingress CRDs
./dgraph_classic_ingress.sh
```

## Cleanup

```bash
./dgraph_clean.sh
```