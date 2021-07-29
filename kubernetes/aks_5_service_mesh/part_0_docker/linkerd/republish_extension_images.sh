#!/usr/bin/env bash
IMAGE_LIST=$(mktemp)

############
# STEP 1: build list of Linkerd Images
#  Requirements: GNU grep is required
############################################
linkerd viz install | grep -F 'cr.l5d.io' | grep -oP '(?<=image: ).*$' | \
  tr -d ' ' | sort | uniq > $IMAGE_LIST
linkerd jaeger install | grep -F 'cr.l5d.io' | grep -oP '(?<=image: ).*$' | \
  tr -d ' ' | sort | uniq >> $IMAGE_LIST

############
# STEP 2: pull linkerd images to the local system
############################################
cat $IMAGE_LIST | xargs -n 1 docker pull

############
# STEP 3: republish (tag, push) to ACR
############################################
for IMAGE in $(cat $IMAGE_LIST); do
  docker tag $IMAGE ${REGISTRY}/${IMAGE#*/}
  docker push ${REGISTRY}/${IMAGE#*/}
done
