#!/usr/bin/env python3
import sys
import os

import grpc
import pydgraph
import certifi

DGRAPH_ALPHA_SERVER = os.getenv('DGRAPH_ALPHA_SERVER') or 'localhost:9080'
SW_SCHEMA_FILE = "sw.schema"
SW_DATA_FILE = "sw.nquads.rdf"


def create_client_stub(addr="localhost:9080"):
    """Create a client stub."""
    # use public trusted root CAs
    with open(certifi.where(), "rb") as f:
        root_ca_cert = f.read()
    creds = grpc.ssl_channel_credentials(root_certificates=root_ca_cert)

    # use grpc secure channel by passing in creds
    return pydgraph.DgraphClientStub(addr=addr, credentials=creds)


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


def main():
    client_stub = create_client_stub(addr=DGRAPH_ALPHA_SERVER)
    client = create_client(client_stub)
    drop_all(client)

    set_schema(client, fname=SW_SCHEMA_FILE)
    create_data(client, fname=SW_DATA_FILE)

    client_stub.close()  # Close the client stub.


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('Error: {}'.format(e))
