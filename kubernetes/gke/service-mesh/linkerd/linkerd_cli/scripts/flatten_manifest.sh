#!/usr/bin/env sh

######
# flatten_manifest.sh
# 
# Description: prints flatten list given K8S manifest in YAML
# Format of Output: 
#   kind: ServiceAccount
#   metadata.name: prometheus
#   ---
#   kind: ClusterRole
#   metadata.name: linkerd-linkerd-viz-tap
#   --- 
#
# Requirements: 
#  * yq tool
#  * GNU Grep (or Grep that supports extended Regexp w -E)
##############################

FLATTEN_YAML='.. | select(. == "*") | {(path | . as $x | (.[] | select((. | tag) == "!!int") |= (["[", ., "]"] | join(""))) | $x | join(".") | sub(".\[", "[")): .} '
cat $1 \
  | yq e "$FLATTEN_YAML" - \
  | grep -E "^kind:|^metadata.name:|^---$"