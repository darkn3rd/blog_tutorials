# Verifies the four cli/ demos each produced a working, AWS-provisioned load
# balancer. Namespace/name defaults below match what each demo script
# actually creates (see cli/0N.*/*.sh); override via env vars if you deployed
# them elsewhere.

def demo_lb_hostname(ingress_or_addresses)
  entry = ingress_or_addresses&.first
  entry&.hostname || entry&.ip || entry&.value
end

control "svc-nlb-demo-ready" do
  title "Service/NLB demo (cli/01.svc_nlb) has a reachable load balancer"
  desc "Applies to the plain-Service demo in cli/01.svc_nlb/svc.sh: the LoadBalancer Service got an NLB hostname/IP from AWS LBC and it answers HTTP requests."
  impact 1.0

  namespace = ENV.fetch("SVC_NLB_NAMESPACE", "demo-nlb")
  name      = ENV.fetch("SVC_NLB_NAME", "demo-nlb-app")

  svc = k8sobject(api: "v1", type: "service", namespace: namespace, name: name)

  describe svc do
    it { should exist }
  end

  next unless svc.exists?

  hostname = demo_lb_hostname(svc.resource.status.loadBalancer&.ingress)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe http("http://#{hostname}/") do
    its("status") { should cmp 200 }
  end
end

control "ing-alb-demo-ready" do
  title "Ingress/ALB demo (cli/02.ing_alb) has a reachable load balancer"
  desc "Applies to the Ingress demo in cli/02.ing_alb/ing.sh: the Ingress got an ALB hostname from AWS LBC and it answers HTTP requests for the demo.example.com host rule."
  impact 1.0

  namespace = ENV.fetch("ING_ALB_NAMESPACE", "default")
  name      = ENV.fetch("ING_ALB_NAME", "demo-alb-app")
  host      = ENV.fetch("ING_ALB_HOST", "demo.example.com")

  ing = k8sobject(api: "networking.k8s.io/v1", type: "ingress", namespace: namespace, name: name)

  describe ing do
    it { should exist }
  end

  next unless ing.exists?

  hostname = demo_lb_hostname(ing.resource.status.loadBalancer&.ingress)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe http("http://#{hostname}/", headers: { "Host" => host }) do
    its("status") { should cmp 200 }
  end
end

control "gw-nlb-demo-ready" do
  title "Gateway/NLB TCPRoute demo (cli/03.gw_nlb) has a reachable load balancer"
  desc "Applies to the Gateway API TCPRoute demo in cli/03.gw_nlb/gwtcp.sh: the Gateway got an NLB hostname/IP from AWS LBC and it answers HTTP requests over the TCP listener."
  impact 1.0

  namespace = ENV.fetch("GW_NLB_NAMESPACE", "demo-gwtcp")
  name      = ENV.fetch("GW_NLB_NAME", "demo-nlb-gateway")

  gw = k8sobject(api: "gateway.networking.k8s.io/v1", type: "gateway", namespace: namespace, name: name)

  describe gw do
    it { should exist }
  end

  next unless gw.exists?

  hostname = demo_lb_hostname(gw.resource.status.addresses)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe http("http://#{hostname}/") do
    its("status") { should cmp 200 }
  end
end

control "gw-alb-demo-ready" do
  title "Gateway/ALB HTTPRoute demo (cli/04.gw_alb) has a reachable load balancer"
  desc "Applies to the Gateway API HTTPRoute demo in cli/04.gw_alb/gwhttp.sh: the Gateway got an ALB hostname from AWS LBC and it answers HTTP requests for the demo.example.com HTTPRoute."
  impact 1.0

  namespace = ENV.fetch("GW_ALB_NAMESPACE", "default")
  name      = ENV.fetch("GW_ALB_NAME", "demo-alb-gw")
  host      = ENV.fetch("GW_ALB_HOST", "demo.example.com")

  gw = k8sobject(api: "gateway.networking.k8s.io/v1", type: "gateway", namespace: namespace, name: name)

  describe gw do
    it { should exist }
  end

  next unless gw.exists?

  hostname = demo_lb_hostname(gw.resource.status.addresses)

  describe "load balancer hostname/IP assigned by AWS LBC" do
    subject { hostname }
    it { should_not be_nil }
  end

  next unless hostname

  describe http("http://#{hostname}/", headers: { "Host" => host }) do
    its("status") { should cmp 200 }
  end
end
