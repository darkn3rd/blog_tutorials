############################################
# Python Dgraph Client Demo for Service Mesh on GCP
# 2022-08-26 by Joaquin Menchaca
#
# Description: Script to populate all required files needed
# to generate  mixed GraphQL (HTTP/1.1) or gRPC (HTTP/2)
# traffic with load balancers, ingress, or service meshes
#
# Tool Requirements:
#   POSIX Shell such as GNU Bash
#   GNU Make
#   docker
#   kubectl
#   helm
#   helmfile
############################################
mkdir -p examples/pydgraph

cat <<-'EOF' > examples/pydgraph/Dockerfile
FROM python:3.9.6-buster
RUN mkdir -p /usr/src/app/data
WORKDIR /usr/src/app

# application package manifest
COPY requirements.txt /usr/src/app/
RUN pip install -r requirements.txt
# application source code
COPY . /usr/src/app

# install packages: jq
RUN apt-get update && apt-get install -y --no-install-recommends jq vim \
	&& rm -rf /var/lib/apt/lists/*

# grpcurl
ADD https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto api.proto
ADD https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_x86_64.tar.gz /usr/src/app
RUN tar -xzf grpcurl_1.8.7_linux_x86_64.tar.gz \
  && rm grpcurl_1.8.7_linux_x86_64.tar.gz \
  && mv grpcurl /usr/local/bin

# download dgraph linux binaries
ADD https://github.com/dgraph-io/dgraph/releases/download/v21.03.2/dgraph-linux-amd64.tar.gz /usr/src/app
RUN tar -xzf dgraph-linux-amd64.tar.gz \
  && rm dgraph-linux-amd64.tar.gz \
  && mv badger dgraph /usr/local/bin

# datasets
ADD https://raw.githubusercontent.com/dgraph-io/benchmarks/master/data/1million.schema /usr/src/app/data/1million.schema
ADD https://github.com/dgraph-io/benchmarks/raw/master/data/1million.rdf.gz /usr/src/app/data/1million.rdf.gz
ADD https://raw.githubusercontent.com/dgraph-io/benchmarks/master/data/21million.schema /usr/src/app/data/21million.schema
ADD https://github.com/dgraph-io/benchmarks/raw/master/data/21million.rdf.gz /usr/src/app/data/21million.rdf.gz

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
EOF

cat <<-'EOF' > examples/pydgraph/helmfile.yaml
repositories:
  - name: itscontained
    url: https://charts.itscontained.io

releases:
  - name: pydgraph-client
    chart: itscontained/raw
    namespace: pydgraph-client
    version:  0.2.5
    values:
      - resources:
          - apiVersion: v1
            kind: ServiceAccount
            metadata:
              name: pydgraph-client
            automountServiceAccountToken: false
            
          - apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: pydgraph-client
            spec:
              replicas: 1
              selector:
                matchLabels:
                  app: pydgraph-client
              template:
                metadata:
                  labels:
                    app: pydgraph-client
                spec:
                  serviceAccountName: dgraph-ratel
                  containers:
                  - name: pydgraph-client
                    image: gcr.io/{{ requiredEnv "GCR_PROJECT_ID" }}/pydgraph-client:latest
                    env:
                    - name: DGRAPH_ALPHA_SERVER
                      value: {{ env "DGRAPH_RELEASE" | default "dgraph" }}-dgraph-alpha.dgraph.svc.cluster.local
                    resources:
                      requests:
                        memory: "64Mi"
                        cpu: "80m"
                      limits:
                        memory: "128Mi"
                        cpu: "250m"

EOF

cat <<-'EOF' > examples/pydgraph/load_data.py
#!/usr/bin/env python3
import sys
from argparse import ArgumentParser

import grpc
import pydgraph
import certifi


def create_client_stub(alpha: str = "localhost:9080", plaintext: bool = False, ca_cert_path: str = None,
                       client_key_path: str = None, client_cert_path: str = None) -> object:
    """Create a client stub."""

    if not plaintext:
        if ca_cert_path:
            # use private root CA
            with open(ca_cert_path, 'rb') as f:
                root_certificates = f.read()

            # use client key/cert for mutualTLS with root CA
            if client_key_path and client_cert_path:
                with open(client_key_path, 'rb') as f:
                    private_key = f.read()
                with open(client_cert_path, 'rb') as f:
                    certificate_chain = f.read()
        else:
            # use public trusted root CAs
            with open(certifi.where(), "rb") as f:
                root_certificates = f.read()
                private_key=None
                certificate_chain=None

        creds = grpc.ssl_channel_credentials(root_certificates=root_certificates,
                                             private_key=private_key,
                                             certificate_chain=certificate_chain)
        # use grpc secure channel by passing in creds
        client_stub = pydgraph.DgraphClientStub(addr=alpha, credentials=creds)
    else:
        client_stub = pydgraph.DgraphClientStub(addr=alpha)

    return client_stub


def create_client(client_stub):
    """Create a client."""
    return pydgraph.DgraphClient(client_stub)


def drop_all(client):
    """Drop All - discard all data and start from a clean slate."""
    return client.alter(pydgraph.Operation(drop_all=True))


def read_file(fname) -> str:
    """Reads a file and returns a string"""

    try:
        file = open(fname, mode='r')
    except FileNotFoundError:
        print(f"File {fname} not found.  Aborting")
        sys.exit(1)
    except OSError:
        print(f"OS error occurred trying to open {fname}")
        sys.exit(1)
    else:
        content = file.read()
        file.close()

    return content


def set_schema(client, fname="sw.schema"):
    """Set schema."""
    schema = read_file(fname)
    return client.alter(pydgraph.Operation(schema=schema))


def create_data(client, fname="sw.nquads.rdf"):
    """Create data using RDF n-quads."""
    p = read_file(fname)
    txn = client.txn()  # Create a new transaction.

    try:
        response = txn.mutate(set_nquads=p)  # run the mutation.
        print(f"Response from mutation:\n{response}\n")  # dump the response
        txn.commit()  # commit the transaction.
    finally:
        txn.discard()  # Clean up. Calling this after txn.commit() is a no-op and hence safe.


def parse_args():
    """Parse command line arguments."""
    parser: ArgumentParser = ArgumentParser(description="An example PyDgraph client script")

    parser.add_argument('--plaintext', action='store_true', default=False, help='Use plain-text HTTP/2 when connecting to server (no TLS).')
    parser.add_argument('--tls-cacert', default=None, help='The CA Cert file used to verify server certificates')
    parser.add_argument('--tls-cert', default=None,
                        help='(optional) The Cert file provided by the client to the server.')
    parser.add_argument('--tls-key', default=None,
                        help='(optional) The private key file provided by the client to the server.')
    parser.add_argument('--files', '-f', required=True, help='Location of rdf n-quad data file')
    parser.add_argument('--schema', '-s', required=True, help='Location of schema file')
    parser.add_argument('--alpha', '-a', default='127.0.0.1:9080',
                        help='Dgraph alpha gRPC server addresses (default "127.0.0.1:9080")')

    return parser.parse_args()


def main():
    args = parse_args()
    client_stub = create_client_stub(alpha=args.alpha, plaintext=args.plaintext, ca_cert_path=args.tls_cacert,
                                     client_key_path=args.tls_key, client_cert_path=args.tls_cert)
    client = create_client(client_stub)
    drop_all(client)

    set_schema(client, fname=args.schema)
    create_data(client, fname=args.files)

    client_stub.close()  # Close the client stub.


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('Error: {}'.format(e))
EOF

cat << "EOF" > examples/pydgraph/Makefile
.PHONY: test build push clean

build:
	@docker build -t pydgraph-client:latest .

push:
	@docker tag pydgraph-client:latest gcr.io/$$GCR_PROJECT_ID/pydgraph-client:latest
	@docker push gcr.io/$$GCR_PROJECT_ID/pydgraph-client:latest

test: build
	@docker run --detach --name pydgraph_client pydgraph-client:latest

scan: build
	@docker scan pydgraph-client:latest

clean:
	@docker stop pydgraph_client && docker rm pydgraph_client

EOF

cat <<-'EOF' > examples/pydgraph/requirements.txt
certifi==2022.6.15
grpcio==1.47.0
protobuf==3.20.1
pydgraph==21.3.2
six==1.16.0

EOF

cat <<-'EOF' > examples/pydgraph/sw.nquads.rdf
_:luke <name> "Luke Skywalker" .
_:luke <dgraph.type> "Person" .
_:leia <name> "Princess Leia" .
_:leia <dgraph.type> "Person" .
_:han <name> "Han Solo" .
_:han <dgraph.type> "Person" .
_:lucas <name> "George Lucas" .
_:lucas <dgraph.type> "Person" .
_:irvin <name> "Irvin Kernshner" .
_:irvin <dgraph.type> "Person" .
_:richard <name> "Richard Marquand" .
_:richard <dgraph.type> "Person" .

_:sw1 <name> "Star Wars: Episode IV - A New Hope" .
_:sw1 <release_date> "1977-05-25" .
_:sw1 <revenue> "775000000" .
_:sw1 <running_time> "121" .
_:sw1 <starring> _:luke .
_:sw1 <starring> _:leia .
_:sw1 <starring> _:han .
_:sw1 <director> _:lucas .
_:sw1 <dgraph.type> "Film" .

_:sw2 <name> "Star Wars: Episode V - The Empire Strikes Back" .
_:sw2 <release_date> "1980-05-21" .
_:sw2 <revenue> "534000000" .
_:sw2 <running_time> "124" .
_:sw2 <starring> _:luke .
_:sw2 <starring> _:leia .
_:sw2 <starring> _:han .
_:sw2 <director> _:irvin .
_:sw2 <dgraph.type> "Film" .

_:sw3 <name> "Star Wars: Episode VI - Return of the Jedi" .
_:sw3 <release_date> "1983-05-25" .
_:sw3 <revenue> "572000000" .
_:sw3 <running_time> "131" .
_:sw3 <starring> _:luke .
_:sw3 <starring> _:leia .
_:sw3 <starring> _:han .
_:sw3 <director> _:richard .
_:sw3 <dgraph.type> "Film" .

_:st1 <name> "Star Trek: The Motion Picture" .
_:st1 <release_date> "1979-12-07" .
_:st1 <revenue> "139000000" .
_:st1 <running_time> "132" .
_:st1 <dgraph.type> "Film" .

EOF

cat <<-'EOF' > examples/pydgraph/sw.schema
name: string @index(term) .
release_date: datetime @index(year) .
revenue: float .
running_time: int .
starring: [uid] .
director: [uid] .

type Person {
  name
}

type Film {
  name
  release_date
  revenue
  running_time
  starring
  director
}

EOF
