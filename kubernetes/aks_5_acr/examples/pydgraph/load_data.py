#!/usr/bin/env python3
import sys
from argparse import ArgumentParser

import grpc
import pydgraph
import certifi


def create_client_stub(alpha: str = "localhost:9080", insecure: str = False, ca_cert_path: str = None,
                       client_key_path: str = None, client_cert_path: str = None) -> object:
    """Create a client stub."""

    if not insecure:
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
    parser: ArgumentParser = argparse.ArgumentParser(description="An example PyDgraph client script")

    parser.add_argument('--insecure', action='store_true', default=False, help='Use cleartext for communication')
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
    client_stub = create_client_stub(alpha=args.alpha, insecure=args.insecure, ca_cert_path=args.tls_cacert,
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
