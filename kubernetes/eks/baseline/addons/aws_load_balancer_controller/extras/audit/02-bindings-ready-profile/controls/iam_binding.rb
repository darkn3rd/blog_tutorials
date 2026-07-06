# Verifies create_lbc_iam_policy() and create_lbc_iam_binding() in
# ../../../install_aws_lbc.sh actually succeeded, for whichever auth mode
# (irsa or pod-identity) and tool (eksctl or aws-cli) were used to run it.

cluster_name = ENV.fetch("EKS_CLUSTER_NAME")
sa_namespace = "kube-system"
sa_name      = "aws-load-balancer-controller"
role_name    = "AmazonEKSLoadBalancerControllerRole"
policy_name  = "AWSLoadBalancerControllerIAMPolicy"

control "lbc-iam-policy-attached" do
  title "AWS LBC IAM policy exists and is attached to the controller role"
  desc "Checks the output of create_lbc_iam_policy() in ../../../install_aws_lbc.sh: " \
       "the AWSLoadBalancerControllerIAMPolicy exists and is attached to " \
       "AmazonEKSLoadBalancerControllerRole."
  impact 1.0

  describe aws_iam_policy(policy_name: policy_name) do
    it { should exist }
  end

  describe aws_iam_role(role_name) do
    it { should exist }
    its("attached_policy_names") { should include(policy_name) }
  end
end

control "lbc-iam-binding-ready" do
  title "ServiceAccount is bound to the IAM role via IRSA or Pod Identity"
  desc "Detects whichever auth mode create_lbc_iam_binding() configured and " \
       "verifies the matching side of the binding (SA annotation for IRSA, " \
       "or the Pod Identity association) is in place."
  impact 1.0

  sa = k8sobject(api: "v1", type: "serviceaccount", namespace: sa_namespace, name: sa_name)

  describe sa do
    it { should exist }
  end

  irsa_role_arn = sa.exists? ? sa.annotations["eks.amazonaws.com/role-arn"] : nil

  if irsa_role_arn
    describe "IRSA role-arn annotation references the LBC role" do
      subject { irsa_role_arn }
      it { should match(/#{role_name}$/) }
    end
  else
    describe aws_eks_pod_identity_association(
      cluster_name: cluster_name,
      namespace: sa_namespace,
      service_account: sa_name
    ) do
      it { should exist }
      its("role_arn") { should match(/#{role_name}$/) }
    end
  end
end
