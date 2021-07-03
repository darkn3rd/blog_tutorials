#!/usr/bin/env python3
import datetime
import json
import sys
import os
import grpc
import ssl

import pydgraph
import certifi

DGRAPH_ALPHA_SERVER = os.getenv('DGRAPH_ALPHA_SERVER') or 'localhost:9080'

def create_client_stub(addr=localhost:9080):
    "Create a client stub."
    ## use public trusted root CAs
    with open(certifi.where(), "rb") as f:
        root_ca_cert = f.read()
    creds = grpc.ssl_channel_credentials(root_certificates=root_ca_cert)

    ## use grpc secure channel by passing in creds
    return pydgraph.DgraphClientStub(addr=addr, credentials=creds)


def create_client(client_stub):
    "Create a client."
    return pydgraph.DgraphClient(client_stub)


def drop_all(client):
    "Drop All - discard all data and start from a clean slate."
    return client.alter(pydgraph.Operation(drop_all=True))


def set_schema(client):
    "Set schema."
    fname = "sw.schema"

    try:
        file = open(fname, mode='r')
    except FileNotFoundError:
        print(f"File {fname} not found.  Aborting")
        sys.exit(1)
    except OSError:
        print(f"OS error occurred trying to open {fname}")
        sys.exit(1)
    else:
        schema = file.read()
        file.close()

    print(f"schema={schema}")
    return client.alter(pydgraph.Operation(schema=schema))


def create_data(client):
    "Create data using RDF n-quads."
    fname = "sw.nquads.rdf"

    try:
        file = open(fname, mode='r')
    except FileNotFoundError:
        print(f"File {fname} not found.  Aborting")
        sys.exit(1)
    except OSError:
        print(f"OS error occurred trying to open {fname}")
        sys.exit(1)
    else:
        p = file.read()
        file.close()

    # Create a new transaction.
    txn = client.txn()
    try:
        print(f"p={p}")

        # Run mutation.
        response = txn.mutate(set_nquads=p)

        # Commit transaction.
        txn.commit()

        # # Get uid of the outermost object (person named "Alice").
        # # response.uids returns a map from blank node names to uids.
        # print('Created person named "Alice" with uid = {}'.format(response.uids['alice']))

    finally:
        # Clean up. Calling this after txn.commit() is a no-op and hence safe.
        txn.discard()



def main():
    client_stub = create_client_stub(addr=DGRAPH_ALPHA_SERVER)
    client = create_client(client_stub)
    set_schema(client)
    create_data(client)

    # Close the client stub.
    client_stub.close()


if __name__ == '__main__':
    try:
        main()
        print('DONE!')
    except Exception as e:
        print('Error: {}'.format(e))