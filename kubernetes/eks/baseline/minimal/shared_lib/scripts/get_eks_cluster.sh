#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$EKS_REGION" "$@"
}

echo "=== EKS Cluster ==="
aws_cli eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint,RoleArn:roleArn,SecurityGroup:resourcesVpcConfig.clusterSecurityGroupId,VpcId:resourcesVpcConfig.vpcId}' \
  --output table

echo "=== Node Groups ==="
for ng in $(aws_cli eks list-nodegroups --cluster-name "$EKS_CLUSTER_NAME" --query 'nodegroups[]' --output text); do
  aws_cli eks describe-nodegroup \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --nodegroup-name "$ng" \
    --query 'nodegroup.{Name:nodegroupName,Status:status,AMI:amiType,Role:nodeRole,Subnets:subnets,InstanceTypes:instanceTypes,Desired:scalingConfig.desiredSize,Min:scalingConfig.minSize,Max:scalingConfig.maxSize}' \
    --output table
done

echo "=== Add-ons ==="
for addon in $(aws_cli eks list-addons --cluster-name "$EKS_CLUSTER_NAME" --query 'addons[]' --output text); do
  aws_cli eks describe-addon \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --addon-name "$addon" \
    --query 'addon.{Name:addonName,Version:addonVersion,Status:status,RoleArn:serviceAccountRoleArn,PodIdentityAssociations:podIdentityAssociations}' \
    --output table
done

echo "=== Pod Identity Associations ==="
aws_cli eks list-pod-identity-associations \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --query 'associations[].{Namespace:namespace,ServiceAccount:serviceAccount,RoleArn:roleArn,AssociationId:associationId}' \
  --output table

echo "=== IAM OIDC Provider ==="
OIDC_URL=$(aws_cli eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --query 'cluster.identity.oidc.issuer' \
  --output text)

echo "$OIDC_URL"

