#!/usr/bin/env bash
TEMP_FILE=$(mktemp)

############
# STEP 1: build list of Linkerd Images
#  Requirements: GNU grep is required
############################################
linkerd viz install | grep -F 'cr.l5d.io' | grep -oP '(?<=image: ).*$' | sort | uniq > $TEMP_FILE
linkerd jaeger install | grep -F 'cr.l5d.io' | grep -oP '(?<=image: ).*$' | sort | uniq >> $TEMP_FILE

############
# STEP 2: pull linkerd images to the local system
############################################
cat $TEMP_FILE | xargs -n 1 docker pull

############
# STEP 3: republish (tag, push) to ACR
############################################
for IMAGE in $(cat $TEMP_FILE); do
  docker tag $IMAGE ${REGISTRY}/${IMAGE#*/}
  docker push ${REGISTRY}/${IMAGE#*/}
done
