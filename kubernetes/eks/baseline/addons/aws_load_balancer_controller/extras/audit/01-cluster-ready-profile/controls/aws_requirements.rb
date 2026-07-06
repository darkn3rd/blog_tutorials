# Cluster-level checks that must pass *before* running install_aws_lbc.sh.
# Mirrors the prerequisites the script itself checks in
# verify_auth_prerequisites() (see ../../../install_aws_lbc.sh).

cluster_name = ENV.fetch("EKS_CLUSTER_NAME")

control "eks-cluster-active" do
  title "EKS cluster exists, is ACTIVE, and runs a supported version"
  desc "install_aws_lbc.sh calls aws eks describe-cluster before doing " \
       "anything else (see discover_cluster_info() in ../../../install_aws_lbc.sh); " \
       "this fails fast if the cluster is missing or still provisioning."
  impact 1.0

  describe aws_eks_cluster(cluster_name: cluster_name) do
    it { should exist }
    its("version") { should cmp >= "1.35" }
  end
end

control "eks-cluster-subnets-tagged" do
  title "Cluster subnets carry the ELB discovery tag AWS LBC needs"
  desc "AWS LBC auto-discovers subnets via the kubernetes.io/role/elb tag " \
       "(see https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/). " \
       "All four cli/ demos request internet-facing load balancers, so at " \
       "least one kubernetes.io/role/elb-tagged subnet is required."
  impact 1.0

  cluster = aws_eks_cluster(cluster_name: cluster_name)
  subnet_tag_sets = cluster.subnet_ids.map { |id| aws_subnet(id).tags || {} }
  public_tagged = subnet_tag_sets.any? { |tags| tags.key?("kubernetes.io/role/elb") }

  describe "at least one subnet tagged kubernetes.io/role/elb" do
    subject { public_tagged }
    it { should eq true }
  end
end

control "eks-lbc-auth-mechanism-ready" do
  title "IRSA OIDC provider or EKS Pod Identity Agent is available"
  desc "install_aws_lbc.sh requires one of these two auth mechanisms to " \
       "already be in place before it can bind IAM permissions to the " \
       "controller (see verify_auth_prerequisites() in ../../../install_aws_lbc.sh)."
  impact 1.0

  cluster = aws_eks_cluster(cluster_name: cluster_name)
  issuer_host = cluster.identity.oidc.issuer.to_s.sub(%r{^https://}, "")

  oidc_ready = !issuer_host.empty? &&
    aws_iam_oidc_providers.arns.any? { |arn| arn.end_with?(issuer_host) }
  pod_identity_ready = aws_eks_addon(
    cluster_name: cluster_name,
    addon_name: "eks-pod-identity-agent"
  ).exists?

  # Each describe is skipped once the other mechanism is confirmed ready,
  # so this reads as an OR gate rather than requiring both.
  describe "IRSA OIDC provider associated with the cluster" do
    subject { oidc_ready }
    it { should eq true } unless pod_identity_ready
  end

  describe "EKS Pod Identity Agent addon installed" do
    subject { pod_identity_ready }
    it { should eq true } unless oidc_ready
  end
end
