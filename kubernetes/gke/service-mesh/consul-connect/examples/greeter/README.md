# Greeter (Python)

This code is based on example from gRPC's [Python/Getting Started](https://grpc.io/docs/languages/python/quickstart/) and Connexion’s [Quickstart](https://connexion.readthedocs.io/en/latest/quickstart.html).  The gRPC example supports reflection and HTTP example support's the Swagger UI.

## Running

### Pyenv + Virtualenv

```bash
pyenv virtualenv $PYTHON_VERSION greeter-$PYTHON_VERSION
pyenv shell greeter-$PYTHON_VERSION
```

### Docker

```bash
docker build --tag greeter-server .
docker run --detach --name greeter_server \
  --publish 9080:9080 --publish 8080:8080 greeter-server:latest
```

#### Publishing the Image

```bash
export DOCKER_REGISTRY="<your_registry_goes_here>"
docker tag greeter-server:latest ${DOCKER_REGISTRY}/greeter-server:latest
docker push ${DOCKER_REGISTRY}/greeter-server:latest
```



# Running the Server

```bash
python greeter_server.py
```

# Testing the client

```bash
grpcurl -plaintext -d '{ "name": "Michihito" }' localhost:9080 helloworld.Greeter/SayHello
# {
#   "message": "Hello, Michihito!"
# }

curl localhost:8080/SayHello/Michihito
# Hello, Michihito!(
```

# Getting Information on API

## gRPC Reflectoin

```bash
grpcurl -plaintext localhost:9080 list
# grpc.reflection.v1alpha.ServerReflection
# helloworld.Greeter
grpcurl -plaintext localhost:9080 describe helloworld.Greeter
# service Greeter {
#   rpc SayHello ( .helloworld.HelloRequest ) returns ( .helloworld.HelloReply );
# }
grpcurl -plaintext localhost:9080 describe .helloworld.HelloRequest
# helloworld.HelloRequest is a message:
# message HelloRequest {
#   string name = 1;
# }
```
