#!/usr/bin/env bash

# Start minikube environment
minikube start --vm-driver=virtualbox

# Deploy Something
kubectl run hello-minikube \
  --image=k8s.gcr.io/echoserver:1.4 \
  --port=8080

kubectl expose deployment hello-minikube \
  --type=NodePort

until kubectl get pod | grep hello-minikube | grep -q running; do sleep 1; done

curl $(minikube service hello-minikube --url)
