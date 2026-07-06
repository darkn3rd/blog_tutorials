# AWS LBC Audit Profiles

Four InSpec profiles that validate the `install_aws_lbc.sh` pipeline
end-to-end, one gate per pipeline stage. Each is independently runnable
right after the corresponding step in
[`../../install_aws_lbc.sh`](../../install_aws_lbc.sh) completes:

| Profile                                                  | Verifies                                                                 | Backend(s)   |
|-----------------------------------------------------------|---------------------------------------------------------------------------|--------------|
| [`01-cluster-ready-profile`](01-cluster-ready-profile)     | EKS cluster exists, subnets are ELB-tagged, IRSA OIDC provider or Pod Identity Agent addon is present | `aws://`     |
| [`02-bindings-ready-profile`](02-bindings-ready-profile)   | Gateway API CRDs installed; IAM role/policy bound via IRSA or Pod Identity | `aws://` + `k8s://` |
| [`03-controller-ready-profile`](03-controller-ready-profile) | AWS LBC deployment healthy, ALB/NLB Gateway API feature gates on, webhook has ready endpoints | `k8s://`     |
| [`04-demos-ready-profile`](04-demos-ready-profile)         | The four `cli/` demos each have a working, reachable load balancer         | `k8s://`     |

Directories are numbered to mirror the pipeline order and the
[`cli/`](../../cli) demo numbering (`01.svc_nlb` … `04.gw_alb`) — run them in
order as you work through the install.

Each profile has its own `inspec.yml`, `controls/`, and `run_tests.sh`. See
each profile's own README for its specific controls and required env vars.

## Tooling

Inspec and CINC Auditor are auditing and Testing Frameworks or Compliance-as-Code. 

These profiles were tested with `cinc-auditor`, but should work with `inspec`.  The `run_tests.sh` script will pick `cinc-auditor` if it is in the path, otherwise `inspec` will be used.

* [cinc-auditor](https://cinc.sh/docs/auditor/) [`cinc-auditor`] - fully open-source distribution of the InSpec runtime
* [Chef InSpec](https://community.chef.io/tools/chef-inspec) [`inspec`] - binary distribution of the InSpec runtime
  * [InSpec Source](https://github.com/inspec/inspec) - source code to InSpec

## Running the tests

Each profile directory has a convenience script to run the tests: `run_tests.sh`. You can use this script or run the tests manually, but will need to follow these steps in general.

```bash
# get temporary credentials for profile configured in $HOME/.aws/config
export AWS_PROFILE="my_profile"
aws login --profile $AWS_PROFILE

# copy temporary credentials to static environment variables
eval $(aws configure export-credentials --format env)

# Run tests in the appropriate profile directory
cinc-auditor exec . -t aws://"${AWS_REGION}"   # 01-cluster-ready-profile
cinc-auditor exec . -t k8s://                  # 02/03/04-*-ready-profile

# Unset temp credentials (important)
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
```

The `unset` matters here specifically because these are commands typed directly
into your interactive shell — `export`/`eval` in that context modifies your
actual shell's environment. `run_tests.sh` doesn't need it: run as `./run_tests.sh`,
it executes as a child process, so the temporary credentials it exports are
discarded with that process on exit and never touch your shell.
