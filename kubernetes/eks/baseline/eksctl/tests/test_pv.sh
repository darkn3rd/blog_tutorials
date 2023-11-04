#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

# create pod with persistent volume
kubectl create namespace "pv-test"

# deploy application with mounted volume
cat <<EOF | kubectl apply --namespace "pv-test" --filename -
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: ubuntu
      command: ["/bin/sh"]
      args: ["-c", "while true; do echo $(date -u) >> /data/out.txt; sleep 5; done"]
      volumeMounts:
      - name: persistent-storage
        mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: ebs-claim
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 4Gi
EOF

