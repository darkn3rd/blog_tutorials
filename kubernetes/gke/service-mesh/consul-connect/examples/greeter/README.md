# Greeter (Python)

This code is based on example from gRPC's [Python/Getting Started](https://grpc.io/docs/languages/python/quickstart/) and Connexion’s [Quickstart](https://connexion.readthedocs.io/en/latest/quickstart.html).  The gRPC example supports reflection and HTTP example support's the Swagger UI.

## Running the Server

### Pyenv + Virtualenv

```bash
pyenv virtualenv $PYTHON_VERSION greeter-$PYTHON_VERSION
pyenv shell greeter-$PYTHON_VERSION
pip install -r requirements.txt
python greeter_server.py
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

## Testing the client

### Pyenv + Virtualenv

```bash
grpcurl -plaintext -d '{ "name": "Michihito" }' localhost:9080 helloworld.Greeter/SayHello
# {
#   "message": "Hello, Michihito!"
# }

curl localhost:8080/SayHello/Michihito
# Hello, Michihito!
```

### Docker

```bash
docker run -t --name greeter_client greeter-server:latest \
  curl localhost:8080/SayHello/Michihito
```


# Getting Information about API

## gRPC Reflection

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

## OpenAPI

```bash
curl localhost:8080/ui
```


# Testing on Kubernetes

1. Deploy Server and Client:
   ```bash
   helmfile --file deploy/deploy.yaml apply
   ```
2. Exec into container:
   ```bash
   GREETER_CLIENT_POD=$(kubectl get pods \
     --selector app=greeter-client \
     --namespace greeter-client \
     --output name
   )
   kubectl exec --tty --stdin \
     --container "greeter-client" \
     --namespace "greeter-client" \
     $GREETER_CLIENT_POD \
     -- bash
   ```
3. Run test:
   ```bash
   SERVER="greeter-server.greeter-server.svc.cluster.local"
   grpcurl -plaintext -d '{ "name": "Michihito" }' $SERVER:9080 helloworld.Greeter/SayHello
   curl $SERVER:8080/SayHello/Michihito
   ```
