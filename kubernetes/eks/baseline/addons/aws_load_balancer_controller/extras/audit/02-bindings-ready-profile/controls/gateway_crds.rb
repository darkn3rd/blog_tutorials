# CRD name lists below were verified against the actual v1.5.0 manifests
# (https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/{standard,experimental}-install.yaml),
# filtered to `kind: CustomResourceDefinition` only. The previous list here
# included "safe-upgrades.gateway.networking.k8s.io", which isn't a CRD at
# all -- it's the name of a ValidatingAdmissionPolicy/Binding pair bundled
# in the same manifest file.

control "gateway-api-standard-crds" do
  title "Verify Kubernetes Gateway API v1.5.0 Standard CRDs"
  desc "Iterates over and verifies the exact matrix of the 8 Custom Resource Definitions included in the stable v1.5.0 standard release channel."
  impact 1.0

  expected_standard_crds = [
    'backendtlspolicies.gateway.networking.k8s.io',
    'gatewayclasses.gateway.networking.k8s.io',
    'gateways.gateway.networking.k8s.io',
    'grpcroutes.gateway.networking.k8s.io',
    'httproutes.gateway.networking.k8s.io',
    'listenersets.gateway.networking.k8s.io',
    'referencegrants.gateway.networking.k8s.io',
    'tlsroutes.gateway.networking.k8s.io'
  ]

  expected_standard_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('group') { should cmp 'gateway.networking.k8s.io' }
    end
  end
end

control "gateway-api-experimental-crds" do
  title "Verify Kubernetes Gateway API v1.5.0 Experimental CRDs"
  desc "Iterates over and verifies the presence of all 12 Custom Resource Definitions packaged in the v1.5.0 experimental release (the 8 standard-channel CRDs, plus TCPRoute/UDPRoute and the two GAMMA mesh CRDs that are experimental-only)."
  impact 1.0

  expected_gateway_crds = [
    'backendtlspolicies.gateway.networking.k8s.io',
    'gatewayclasses.gateway.networking.k8s.io',
    'gateways.gateway.networking.k8s.io',
    'grpcroutes.gateway.networking.k8s.io',
    'httproutes.gateway.networking.k8s.io',
    'listenersets.gateway.networking.k8s.io',
    'referencegrants.gateway.networking.k8s.io',
    'tcproutes.gateway.networking.k8s.io',
    'tlsroutes.gateway.networking.k8s.io',
    'udproutes.gateway.networking.k8s.io'
  ]

  expected_gateway_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('group') { should cmp 'gateway.networking.k8s.io' }
    end
  end

  expected_gamma_crds = [
    'xbackendtrafficpolicies.gateway.networking.x-k8s.io',
    'xmeshes.gateway.networking.x-k8s.io'
  ]

  expected_gamma_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('group') { should cmp 'gateway.networking.x-k8s.io' }
    end
  end
end

control "aws-lbc-gateway-extensions-crds" do
  title "Verify AWS Load Balancer Controller Gateway API CRDs"
  desc "Asserts that the custom AWS-specific load balancer and listener rule configuration extensions are deployed."
  impact 1.0

  expected_aws_gateway_crds = [
    'listenerruleconfigurations.gateway.k8s.aws',
    'loadbalancerconfigurations.gateway.k8s.aws',
    'targetgroupconfigurations.gateway.k8s.aws'
  ]

  expected_aws_gateway_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('group') { should cmp 'gateway.k8s.aws' }
    end
  end
end
