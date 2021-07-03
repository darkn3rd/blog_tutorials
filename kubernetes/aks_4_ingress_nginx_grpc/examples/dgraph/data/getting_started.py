#!/usr/bin/env python3
import datetime
import json
import sys

import pydgraph


# Create a client stub.
def create_client_stub():
    return pydgraph.DgraphClientStub('localhost:9080')


# Create a client.
def create_client(client_stub):
    return pydgraph.DgraphClient(client_stub)


# Drop All - discard all data and start from a clean slate.
def drop_all(client):
    return client.alter(pydgraph.Operation(drop_all=True))


# Set schema.
def set_schema(client):
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

    return client.alter(pydgraph.Operation(schema=schema))


# Create data using JSON.
def create_data(client):
    fname = "sw.rdf"

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
    client_stub = create_client_stub()
    client = create_client(client_stub)
    # set_schema(client)
    # create_data(client)

    # Close the client stub.
    client_stub.close()


if __name__ == '__main__':
    try:
        main()
        print('DONE!')
    except Exception as e:
        print('Error: {}'.format(e))
