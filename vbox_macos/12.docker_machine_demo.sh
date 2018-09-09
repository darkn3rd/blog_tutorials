#!/usr/bin/env bash

# Create a docker machine environment
docker-machine create --driver virtualbox default

# Tell docker engine to use our machine's docker
eval $(docker-machine env default)

# Run a container form docker hub
docker run docker/whalesay cowsay Hello World
