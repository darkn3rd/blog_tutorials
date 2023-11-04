#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

kubectl apply --namespace ratel --filename - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ratel-deny-egress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - {}
  egress:
    - to:
        - ipBlock:
            cidr: "0.0.0.0/0"
            except:
              - "10.0.0.0/8"
              - "172.16.0.0/12"
              - "192.168.0.0/16"
EOF
