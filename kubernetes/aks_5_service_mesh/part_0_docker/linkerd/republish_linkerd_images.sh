#!/usr/bin/env bash
IMAGE_LIST=$(mktemp)
SCRATCH_FILE=$(mktemp)

############
# STEP 1: build list of Linkerd Images
#  Requirements: GNU grep is required
############################################

# extract image: "registry/org/name:version"
linkerd install --ignore-cluster | grep -F 'cr.l5d.io' | \
  grep -oP '(?<=image:).*$' | tr -d ' ' | sort | uniq > $TEMP_FILE

# extract image: {} from config maps
linkerd install --ignore-cluster | \
  grep -Pzo '(?s)\s*name: cr.l5d.io/.*?version:\N*' | tr '\0' '\n' > $SCRATCH_FILE
while read -r LINE; do
  if grep -q version <<< $LINE; then
    VERSION=$(grep -oP '(?<=version: ).*$' <<< $LINE)
    if ! grep -q $NAME:$VERSION $TEMP_FILE; then
      echo $NAME:$VERSION >> $TEMP_FILE
    fi
  elif grep -q name <<< $LINE; then
    NAME=$(grep -oP '(?<=name: ).*$' <<< $LINE)
  fi
done < $SCRATCH_FILE

############
# STEP 2: pull linkerd images to the local system
############################################
cat $TEMP_FILE | xargs -n 1 docker pull

############
# STEP 3: republish (tag, push) to ACR
############################################
for IMAGE in $($TEMP_FILE); do
  docker tag $IMAGE ${REGISTRY}/${IMAGE#*/}
  docker push ${REGISTRY}/${IMAGE#*/}
done
