# AWS LBC Audit Profiles

Four **InSpec** profiles for validating the prerequisites, installation, and demonstration workloads for the **AWS Load Balancer Controller** (**AWS LBC**). They are designed to be run sequentially as you progress through the installation, but each profile can also be executed independently.

| Profile                                                  | Verifies                                                                 | Backend(s)   |
|-----------------------------------------------------------|---------------------------------------------------------------------------|--------------|
| [`01-cluster-ready-profile`](01-cluster-ready-profile)     | EKS cluster exists, subnets are ELB tagged, IRSA OIDC provider or EKS Pod Identity Agent add-on is present | `aws://`     |
| [`02-bindings-ready-profile`](02-bindings-ready-profile)   | Gateway API CRDs installed; IAM role and policy configured for IRSA or EKS Pod Identity | `aws://` + `k8s://` |
| [`03-controller-ready-profile`](03-controller-ready-profile) | AWS LBC deployment healthy, ALB/NLB Gateway API feature gates on, webhook has ready endpoints | `k8s://`     |
| [`04-demos-ready-profile`](04-demos-ready-profile)         | Demo workloads expose reachable Application or Network Load Balancers         | `k8s://`     |

Each profile has its own `inspec.yml`, `controls/`, and `run_tests.sh`. See
each profile's own README for its specific controls and required env vars.

## Backend Summary

| Backend  | Used for                                                                    |
| -------- | --------------------------------------------------------------------------- |
| `aws://` | AWS resources (VPCs, IAM, subnets, EKS configuration)                       |
| `k8s://` | Kubernetes resources (CRDs, controllers, services, webhooks, and workloads) |


## Tooling

**InSpec** and **CINC Auditor** are Compliance-as-Code frameworks used to audit infrastructure and validate system configuration.

These profiles were tested with `cinc-auditor`, but should work with `inspec`.  The `run_tests.sh` script will pick `cinc-auditor` if it is in the path, otherwise `inspec` will be used.

* [cinc-auditor](https://cinc.sh/docs/auditor/) [`cinc-auditor`] - fully open-source distribution of the InSpec runtime
* [Chef InSpec](https://community.chef.io/tools/chef-inspec) [`inspec`] - binary distribution of the InSpec runtime
  * [InSpec Source](https://github.com/inspec/inspec) - source code to InSpec

## Prerequisites

1. Access to AWS
   ```bash
   # get temporary credentials for profile configured in $HOME/.aws/config
   export AWS_PROFILE="my_profile"
   aws login --profile $AWS_PROFILE
   ```
2. EKS Cluster provisioned
3. Kubernetes client configured (`KUBECONFIG`)
   ```bash
   export KUBECONFIG="$HOME/.kube/aws/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"
   aws eks update-kubeconfig \
     --name "$EKS_CLUSTER_NAME" \
     --region "$EKS_REGION" \
     --kubeconfig "$KUBECONFIG"
   ```
4. AWS Load Balancer Controller prerequisites configured (CRDs, IAM role/policy, and either IRSA or Pod Identity)
5. AWS Load Balancer Controller installed
6. Demo workloads deployed (optional, required only for Profile 04)

## Quickstart

Most users can simply run `./run_tests.sh`; the script performs the required AWS authentication and selects the appropriate InSpec runtime automatically.

```bash
pushd 01-cluster-ready-profile
export AWS_PROFILE="my_profile"
./run_tests.sh
popd
```

## Running the tests

Each profile includes a `run_tests.sh` script that handles authentication and invokes the appropriate audit backend. This is the recommended way to execute the profiles. The commands below illustrate the equivalent manual process.

> 📝 **NOTE** Those unfamiliar with AWS CLI v2 login might wonder why `aws login` isn't enough. The AWS CLI stores temporary credentials in its credential cache after `aws login`. Since **InSpec** reads credentials from the standard AWS SDK environment variables, export the cached credentials before running the profiles.

Run the following commands from the desired profile directory.

```bash
# copy temporary credentials to static environment variables
eval $(aws configure export-credentials --format env)
```

**Profile 02** validates both AWS IAM configuration and Kubernetes resources, so it requires both the `aws://` and `k8s://` backends.

```bash
# Run tests in the appropriate profile directory
cinc-auditor exec . -t aws://"${AWS_REGION}"   # 01-cluster-ready-profile
cinc-auditor exec . -t k8s://                  # 02/03/04-*-ready-profile
```

> ⚠️ **IMPORTANT**: The manual steps above modify your current shell by exporting temporary AWS credentials. Be sure to unset them when you're finished. This cleanup is not required when using `./run_tests.sh`, because the script runs in its own process and any exported credentials disappear when it exits.

```bash
# Unset temp credentials (important)
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
```
