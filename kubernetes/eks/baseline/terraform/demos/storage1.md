

## Setup

```
kubectl get storageclass ebs-gp3 >/dev/null 2>&1 || \
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF
```

## Craete

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply --filename - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pvc-demo
spec:
  containers:
    - name: busybox
      image: busybox:1.37
      command:
        - sh
        - -c
        - |
          echo "Started at $(date)" >> /data/demo.txt
          sleep infinity
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: demo-pvc
EOF
```

## Test

```bash
kubectl exec pvc-demo -- cat /data/demo.txt
kubectl delete pod pvc-demo
kubectl apply --filename - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pvc-demo
spec:
  containers:
    - name: busybox
      image: busybox:1.37
      command:
        - sh
        - -c
        - |
          echo "Started at $(date)" >> /data/demo.txt
          sleep infinity
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: demo-pvc
EOF
kubectl exec pvc-demo -- cat /data/demo.txt
```

## Cleanup

```bash
kubectl delete pod pvc-demo
kubectl delete pvc demo-pvc
```