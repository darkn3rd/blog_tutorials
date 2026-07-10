# Verifies the AWS LBC deployment itself is healthy and ready to serve,
# independent of what installed it or how its IAM binding was set up.

deployment_name = "aws-load-balancer-controller"
sa_namespace    = "kube-system"
webhook_service = "aws-load-balancer-webhook-service"

control "lbc-deployment-healthy" do
  title "AWS LBC controller deployment is running with all replicas ready"
  desc "The aws-load-balancer-controller Deployment exists and every " \
       "desired replica is ready."
  impact 1.0

  dep = k8s_deployment(namespace: sa_namespace, name: deployment_name)

  describe dep do
    it { should exist }
  end

  next unless dep.exists?

  ready_replicas = dep.resource.status.readyReplicas.to_i
  desired_replicas = dep.resource.status.replicas.to_i

  describe "ready replicas (#{ready_replicas}/#{desired_replicas})" do
    subject { ready_replicas }
    it { should be >= 1 }
    it { should cmp desired_replicas }
  end
end

control "lbc-gateway-feature-gates-enabled" do
  title "ALB and NLB Gateway API feature gates are enabled on the controller"
  desc "Checks the controller's --feature-gates flag directly, matching " \
       "what controllerConfig.featureGates in the Helm values sets."
  impact 1.0

  dep = k8s_deployment(namespace: sa_namespace, name: deployment_name)
  next unless dep.exists?

  args = dep.resource.spec.template.spec.containers[0].args || []
  feature_gates_arg = args.find { |a| a.to_s.start_with?("--feature-gates=") }.to_s

  describe feature_gates_arg do
    it { should match(/ALBGatewayAPI=true/) }
    it { should match(/NLBGatewayAPI=true/) }
  end
end

control "lbc-webhook-service-ready" do
  title "AWS LBC admission webhook service has healthy endpoints"
  desc "The controller registers ALB/NLB validating & mutating webhooks; if " \
       "the webhook Service has no ready endpoints, applying any " \
       "Ingress/Service/Gateway resource AWS LBC processes will hang or be " \
       "rejected by the API server."
  impact 1.0

  svc = k8sobject(api: "v1", type: "services", namespace: sa_namespace, name: webhook_service)

  describe svc do
    it { should exist }
  end

  next unless svc.exists?

  endpoints = k8sobject(api: "v1", type: "endpoints", namespace: sa_namespace, name: webhook_service)
  ready_addresses = endpoints.exists? ? (endpoints.resource.subsets || []).flat_map { |s| s.addresses || [] } : []

  describe "ready webhook endpoint addresses" do
    subject { ready_addresses.length }
    it { should be >= 1 }
  end
end
