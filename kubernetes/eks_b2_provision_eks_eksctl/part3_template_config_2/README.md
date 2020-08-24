# Template Cluster Configuration 2


## Create VPC and Cluster Configuration

```bash
# fetch modules and providers
terraform init

# list resources that will be created
terraform plan

# provision VPC and create eksctl file
terraform apply
```


## Provision EKS Using Cluster Configuration

```bash
eksctl create cluster --config-file ./cluster_config.yaml
```

## Clean Up


### Delete EKS Cluster

```bash
eksctl delete cluster --config-file ./cluster_config.yaml
```


### Delete VPC

```bash
terraform destroy
```
