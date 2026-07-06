# Verifies the LBC IAM role/policy binding succeeded, regardless of which
# install path (and tool) created it. The controller's IAM role name is
# NOT predictable in general:
#   - install_aws_lbc.sh's aws-cli mode always names it
#     "AmazonEKSLoadBalancerControllerRole" (ROLE_NAME in that script).
#   - The Terraform IRSA module names it
#     "${eks_cluster_name}-aws-load-balancer-controller" (see
#     aws_iam_role.aws_load_balancer_controller in
#     eks_terraform_project/modules/load_balancer_controller/lbc_irsa/main.tf).
#   - install_aws_lbc.sh's eksctl mode (both irsa and pod-identity) never
#     passes --role-name, so eksctl auto-generates the role via
#     CloudFormation with a random suffix -- there is no fixed name to
#     hardcode at all for this path.
#
# So instead of guessing a name, this discovers the role the same way
# check_aws_lbc_status.sh's determine_auth_mode() does: read it off the
# ServiceAccount's IRSA annotation (set identically by eksctl, the aws-cli
# path, and the Terraform module -- it's the standard EKS Pod Identity
# Webhook contract, not something each tool invents independently), or
# fall back to the Pod Identity association if the annotation is absent.

cluster_name = ENV.fetch("EKS_CLUSTER_NAME")
sa_namespace = "kube-system"
sa_name      = "aws-load-balancer-controller"
policy_name  = "AWSLoadBalancerControllerIAMPolicy"

sa = k8sobject(api: "v1", type: "serviceaccounts", namespace: sa_namespace, name: sa_name)
# .annotations comes back from k8s-ruby's RecursiveOpenStruct wrapping of the
# raw API response; dotted/slashed keys like this one aren't valid Ruby
# method names, so whether they land as String or Symbol keys underneath is
# not something to assume -- normalize before lookup.
sa_annotations = sa.exists? ? sa.annotations.to_h.transform_keys(&:to_s) : {}
irsa_role_arn = sa_annotations["eks.amazonaws.com/role-arn"]

pod_identity_association = nil
role_arn = irsa_role_arn
if role_arn.nil?
  pod_identity_association = aws_eks_pod_identity_association(
    cluster_name: cluster_name,
    namespace: sa_namespace,
    service_account: sa_name
  )
  role_arn = pod_identity_association.role_arn
end
role_name = role_arn.to_s.split("/").last

control "lbc-iam-binding-ready" do
  title "ServiceAccount is bound to an IAM role via IRSA or Pod Identity"
  desc "Detects whichever auth mode bound the controller's ServiceAccount " \
       "to an IAM role and verifies that binding actually resolved to a role."
  impact 1.0

  describe sa do
    it { should exist }
  end

  if irsa_role_arn
    describe "IRSA role-arn annotation" do
      subject { irsa_role_arn }
      it { should_not be_empty }
    end
  else
    describe pod_identity_association do
      it { should exist }
      its("role_arn") { should_not be_nil }
    end
  end
end

control "lbc-iam-policy-attached" do
  title "The controller's IAM role has the AWS LBC policy attached"
  desc "Whichever role lbc-iam-binding-ready discovered (from the IRSA " \
       "annotation or the Pod Identity association), verifies " \
       "AWSLoadBalancerControllerIAMPolicy exists and is attached to it."
  impact 1.0

  describe aws_iam_policy(policy_name: policy_name) do
    it { should exist }
  end

  describe "IAM role discovered from the ServiceAccount binding" do
    subject { role_name.to_s }
    it { should_not be_empty }
  end

  next if role_name.to_s.empty?

  describe aws_iam_role(role_name) do
    it { should exist }
    its("attached_policy_names") { should include(policy_name) }
  end
end
