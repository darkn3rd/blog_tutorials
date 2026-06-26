#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"
: "${EKS_VERSION:?EKS_VERSION is required}"

cat <<EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $EKS_CLUSTER_NAME
  region: $EKS_REGION
  version: "$EKS_VERSION"

managedNodeGroups:
  - name: ng-1
    instanceType: m6i.large
    desiredCapacity: 3
    minSize: 3
    maxSize: 3
    labels:
      alpha.eksctl.io/cluster-name: $EKS_CLUSTER_NAME
      alpha.eksctl.io/nodegroup-name: ng-1
    tags:
      alpha.eksctl.io/nodegroup-name: ng-1
      alpha.eksctl.io/nodegroup-type: managed

iam:
  withOIDC: true

addonsConfig:
  autoApplyPodIdentityAssociations: true

addons:
  - name: vpc-cni
    useDefaultPodIdentityAssociations: true
  - name: aws-ebs-csi-driver
    useDefaultPodIdentityAssociations: true
  - name: eks-pod-identity-agent
EOF

mkdir -p ~/.kube/aws
export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

eksctl create cluster --config-file cluster.yaml
