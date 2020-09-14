# Azure Blob Storage

This contains scripts useful in creating Azure Blob and testing it with Azure MinIO Azure Gateway.

## Create Azure Blob

```bash
export MY_RESOURCE_GROUP=my-superfun-resources
export MY_LOCATION=eastus2
export MY_STORAGE_ACCT=my0new0unique0storage
export MY_CONTAINER_NAME=storage-blob-test
./create_blob.sh
````

## Upload and Verify Files

```bash
export MY_RESOURCE_GROUP=my-superfun-resources
export MY_STORAGE_ACCT=my0new0unique0storage

touch hello1 hello2 hello3
az storage blob upload \
  --account-name ${MY_STORAGE_ACCT} \
  --container-name ${MY_CONTAINER_NAME} \
  --name helloworld \
  --file helloworld \
  --auth-mode login

az storage blob list \
  --account-name ${MY_STORAGE_ACCT} \
  --container-name ${MY_CONTAINER_NAME} \
  --auth-mode login | jq '.[].name'
```

## Docker Environment

```bash
export MY_RESOURCE_GROUP=my-superfun-resources
export MY_STORAGE_ACCT=my0new0unique0storage
./crreate_env.sh

docker-compose build
docker-compose up --detach
```

## Test MinIO Gateway

```bash
export MY_CONTAINER_NAME=storage-blob-test

docker exec --tty azure-client mc ls myazure/$MY_CONTAINER_NAME
docker exec --tty azure-client s3cmd ls s3://$MY_CONTAINER_NAME
```

## Cleanup Local Resources

```bash
docker-compose stop && docker-compose rm
```

## Cleanup Azure Resources

```bash
export MY_RESOURCE_GROUP=my-superfun-resources
export MY_STORAGE_ACCT=my0new0unique0storage
export MY_CONTAINER_NAME=storage-blob-test
./delete_blob.sh
```
