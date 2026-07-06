# Stage 3: Controller Ready

Verifies the AWS Load Balancer Controller itself — installed by
`install_lbc_helm_chart()` in
[`../../../install_aws_lbc.sh`](../../../install_aws_lbc.sh) — is healthy and
functional, independent of which auth mode/tool provisioned its IAM binding.

Controls (`controls/controller_requirements.rb`):

* `lbc-deployment-healthy` — the `aws-load-balancer-controller` Deployment
  exists and all its replicas are ready.
* `lbc-gateway-feature-gates-enabled` — the controller's `--feature-gates`
  flag has both `ALBGatewayAPI=true` and `NLBGatewayAPI=true`, matching
  `controllerConfig.featureGates` in the Helm values.
* `lbc-webhook-service-ready` — the admission webhook Service exists and has
  at least one ready endpoint (a Service with no endpoints means every
  Ingress/Service/Gateway apply the controller's webhook intercepts will
  hang or get rejected).

## Required environment variables

None — only needs a working `KUBECONFIG`/cluster context.

## Run

```bash
./run_tests.sh
```

Runs against `-t k8s://`.
