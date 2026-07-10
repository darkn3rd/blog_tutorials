# Verifies four representative workloads (Service/NLB, Ingress/ALB,
# Gateway+TCPRoute/NLB, Gateway+HTTPRoute/ALB) each got a working,
# AWS-provisioned load balancer. Namespace/name defaults below are just
# that -- defaults; override via the *_NAMESPACE/*_NAME/*_HOST env vars
# below if you deployed them under different names.

# Local (not top-level def): a `def` here would be evaluated against a
# different receiver inside each `control do...end` block (an
# Inspec::Rule, not this file's top-level self) and raise NoMethodError --
# confirmed by hitting exactly that error. A local variable holding a Proc
# is captured by the block's normal lexical closure instead, same as any
# other local used inside these controls.
demo_lb_hostname = lambda do |ingress_or_addresses|
  entry = ingress_or_addresses&.first
  entry&.hostname || entry&.ip || entry&.value
end

# Not InSpec's own `http` resource: it declares `supports platform: "unix"`
# / `"windows"` (see http.rb in inspec-core), which InSpec's resource
# framework enforces before the resource even runs, regardless of what it
# does internally -- confirmed by hitting exactly "Unsupported
# resource/backend combination: http / k8s" under -t k8s://. Plain
# Net::HTTP has no such restriction since it isn't an InSpec resource at
# all, just stdlib Ruby running inline in the control body.
require "net/http"
require "uri"

http_status = lambda do |hostname, host_header: nil|
  uri = URI("http://#{hostname}/")
  req = Net::HTTP::Get.new(uri)
  req["Host"] = host_header if host_header
  begin
    Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |http|
      http.request(req).code.to_i
    end
  rescue StandardError
    nil
  end
end

control "svc-nlb-demo-ready" do
  title "Service/NLB demo has a reachable load balancer"
  desc "The LoadBalancer Service in the Service/NLB demo got an NLB hostname/IP from AWS LBC and it answers HTTP requests."
  impact 1.0

  namespace = ENV.fetch("SVC_NLB_NAMESPACE", "demo-nlb")
  name      = ENV.fetch("SVC_NLB_NAME", "demo-nlb-app")

  svc = k8sobject(api: "v1", type: "services", namespace: namespace, name: name)

  describe svc do
    it { should exist }
  end

  next unless svc.exists?

  hostname = demo_lb_hostname.call(svc.resource.status.loadBalancer&.ingress)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe "HTTP response from #{hostname}" do
    subject { http_status.call(hostname) }
    it { should cmp 200 }
  end
end

control "ing-alb-demo-ready" do
  title "Ingress/ALB demo has a reachable load balancer"
  desc "The Ingress in the Ingress/ALB demo got an ALB hostname from AWS LBC and it answers HTTP requests for the demo.example.com host rule."
  impact 1.0

  namespace = ENV.fetch("ING_ALB_NAMESPACE", "demo-alb")
  name      = ENV.fetch("ING_ALB_NAME", "demo-alb-app")
  host      = ENV.fetch("ING_ALB_HOST", "demo.example.com")

  ing = k8sobject(api: "networking.k8s.io/v1", type: "ingresses", namespace: namespace, name: name)

  describe ing do
    it { should exist }
  end

  next unless ing.exists?

  hostname = demo_lb_hostname.call(ing.resource.status.loadBalancer&.ingress)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe "HTTP response from #{hostname} (Host: #{host})" do
    subject { http_status.call(hostname, host_header: host) }
    it { should cmp 200 }
  end
end

control "gw-nlb-demo-ready" do
  title "Gateway/NLB TCPRoute demo has a reachable load balancer"
  desc "The Gateway in the Gateway+TCPRoute/NLB demo got an NLB hostname/IP from AWS LBC and it answers HTTP requests over the TCP listener."
  impact 1.0

  namespace = ENV.fetch("GW_NLB_NAMESPACE", "demo-gwtcp")
  name      = ENV.fetch("GW_NLB_NAME", "demo-gwtcp-app-gateway")

  gw = k8sobject(api: "gateway.networking.k8s.io/v1", type: "gateways", namespace: namespace, name: name)

  describe gw do
    it { should exist }
  end

  next unless gw.exists?

  hostname = demo_lb_hostname.call(gw.resource.status.addresses)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe "HTTP response from #{hostname}" do
    subject { http_status.call(hostname) }
    it { should cmp 200 }
  end
end

control "gw-alb-demo-ready" do
  title "Gateway/ALB HTTPRoute demo has a reachable load balancer"
  desc "The Gateway in the Gateway+HTTPRoute/ALB demo got an ALB hostname from AWS LBC and it answers HTTP requests for the demo.example.com HTTPRoute."
  impact 1.0

  namespace = ENV.fetch("GW_ALB_NAMESPACE", "demo-gwhttp")
  name      = ENV.fetch("GW_ALB_NAME", "demo-gwhttp-app-gw")
  host      = ENV.fetch("GW_ALB_HOST", "demo.example.com")

  gw = k8sobject(api: "gateway.networking.k8s.io/v1", type: "gateways", namespace: namespace, name: name)

  describe gw do
    it { should exist }
  end

  next unless gw.exists?

  hostname = demo_lb_hostname.call(gw.resource.status.addresses)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe "HTTP response from #{hostname} (Host: #{host})" do
    subject { http_status.call(hostname, host_header: host) }
    it { should cmp 200 }
  end
end
