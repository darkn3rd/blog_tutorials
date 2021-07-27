# aks-ssh

This is a small utility container with some tools useful in troubleshooting and debugging the cluster.

## Building

```bash
az acr login --name ${AZ_ACR_NAME}

make build && make push

# verify results
az acr repository list --name ${AZ_ACR_NAME} --output table
```

## Running the Container

```bash
kubectl run aks-ssh --image=${AZ_ACR_LOGIN_SERVER}/aks-ssh:latest --image-pull-policy=Always

# set this to private key that has access to AKS Worker Nodes (VMSS machines)
AZ_SSH_KEY_PATH=~/.ssh/id_rsa
kubectl cp $AZ_SSH_KEY_PATH aks-ssh:/root/.ssh

# exec into container
kubectl exec -it aks-ssh --/bin/bash
```

## Connecting to Servers

```bash
chown root:root .ssh/id_rsa
ssh azureuser@$server_ip
```
