#!/usr/bin/env bash

gcloud container clusters create \
  --cluster-version 1.14.10-gke.36 \
  --region us-west1 \
  --machine-type n1-standard-2 \
  --num-nodes 1 \
  --min-nodes 1 \
  --max-nodes 4 \
  my-demo
