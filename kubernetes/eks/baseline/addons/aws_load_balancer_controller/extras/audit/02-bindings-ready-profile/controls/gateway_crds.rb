control "gateway-api-standard-crds" do
  title "Verify Kubernetes Gateway API v1.5.0 Standard CRDs"
  desc "Iterates over and verifies the exact matrix of the 6 Custom Resource Definitions included in the stable v1.5.0 standard release channel."
  impact 1.0

  expected_standard_crds = [
    'backendtlspolicies.gateway.networking.k8s.io',
    'gatewayclasses.gateway.networking.k8s.io',
    'gateways.gateway.networking.k8s.io',
    'grpcroutes.gateway.networking.k8s.io',
    'httproutes.gateway.networking.k8s.io',
    'listenersets.gateway.networking.k8s.io',
    'referencegrants.gateway.networking.k8s.io',
    'safe-upgrades.gateway.networking.k8s.io',
    'tlsroutes.gateway.networking.k8s.io'
  ]

  # Cleaned up: Using the valid singular resource framework directly inside the array loop
  expected_standard_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('spec.group') { should cmp 'gateway.networking.k8s.io' }
    end
  end
end

control "gateway-api-experimental-crds" do
  title "Verify Kubernetes Gateway API v1.5.0 Experimental CRDs"
  desc "Iterates over and verifies the presence of all 7 core Custom Resource Definitions packaged in the v1.5.0 experimental release."
  impact 1.0

  expected_gateway_crds = [
    'gatewayclasses.gateway.networking.k8s.io',
    'gateways.gateway.networking.k8s.io',
    'grpcroutes.gateway.networking.k8s.io',
    'httproutes.gateway.networking.k8s.io',
    'listenersets.gateway.networking.k8s.io',
    'referencegrants.gateway.networking.k8s.io',
    'safe-upgrades.gateway.networking.k8s.io',
    'tcproutes.gateway.networking.k8s.io',
    'tlsroutes.gateway.networking.k8s.io',
    'udproutes.gateway.networking.k8s.io'
  ]

  expected_gateway_crds.each do |crd_name|
    describe k8s_custom_resource_definition(name: crd_name) do
      it { should exist }
      its('spec.group') { should cmp 'gateway.networking.k8s.io' }
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
      its('spec.group') { should cmp 'gateway.k8s.aws' }
    end
  end
end
