#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'helm' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${INGRESS_ADDRS}" ]] && { echo 'INGRESS_ADDRS not specified. Aborting' 1>&2 ; exit 1; }


# deploy network policy to dgraph namespace
kubectl apply --namespace dgraph --filename - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dgraph-allow
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
    - from:
$(P="    "; for IP in ${INGRESS_ADDRS[*]}; 
    do printf -- "$P$P- ipBlock:\n$P$P${P}cidr: $IP/32\n"; 
  done
)
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: dgraph-client
      ports:
        - port: 8080
        - port: 9080
EOF
