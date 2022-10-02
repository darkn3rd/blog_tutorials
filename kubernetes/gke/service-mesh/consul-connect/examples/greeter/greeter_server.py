# Copyright 2018 The gRPC Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""The reflection-enabled version of gRPC helloworld.Greeter server."""

from concurrent import futures
import logging

import grpc
from grpc_reflection.v1alpha import reflection
import helloworld_pb2
import helloworld_pb2_grpc
import connexion

def health() -> str:
    return 'ok\n'


def SayHello(name) -> str:
    return 'Hello, %s!\n' % name


app = connexion.FlaskApp(__name__, specification_dir='openapi/')
@app.route('/')
def default() -> str:
    return 'Pydgraph Client Utility.\nSee supported API with http(s)://<server_hostname>:<port>/ui. \n'


class Greeter(helloworld_pb2_grpc.GreeterServicer):

    def SayHello(self, request, context):
        return helloworld_pb2.HelloReply(message='Hello, %s!' % request.name)


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    helloworld_pb2_grpc.add_GreeterServicer_to_server(Greeter(), server)
    SERVICE_NAMES = (
        helloworld_pb2.DESCRIPTOR.services_by_name['Greeter'].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)
    server.add_insecure_port('[::]:9080')
    server.start()
    #server.wait_for_termination()

    app.add_api('api.yaml', arguments={'title': 'Pydgraph Client'})
    app.run(host='0.0.0.0', port=8080, debug=False)

    try:
        while True:
            time.sleep(_ONE_DAY_IN_SECONDS)
    except KeyboardInterrupt:
        server.stop(grace=0)



if __name__ == '__main__':
    logging.basicConfig()
    serve()
