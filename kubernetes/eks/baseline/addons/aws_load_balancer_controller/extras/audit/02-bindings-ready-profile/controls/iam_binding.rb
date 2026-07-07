require "json"
require "net/http"
require "set"
require "uri"

# Verifies the LBC IAM role/policy binding succeeded, regardless of which
# install path (and tool) created it. The controller's IAM role name is
# NOT predictable in general:
#   - install_aws_lbc.sh's aws-cli mode always names it
#     "AmazonEKSLoadBalancerControllerRole" (ROLE_NAME in that script).
#   - The Terraform module defaults to
#     "${eks_cluster_name}-aws-load-balancer-controller", but that's
#     overridable per root via var.role_name -- see
#     aws_iam_role.aws_load_balancer_controller in
#     eks_terraform_project/modules/load_balancer_controller/lbc_auth/role.tf.
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

# Same canonical source, and the same Gateway-API amendment, that
# lbc_auth/role.tf and install_aws_lbc.sh's create_lbc_iam_policy() both
# apply. Whatever install path built the role's policy, this is the actual
# permission set the controller needs to function -- not a name.
upstream_policy_url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
gateway_api_actions  = %w(
  elasticloadbalancing:DescribeListenerAttributes
  elasticloadbalancing:ModifyListenerAttributes
)

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

# Normalizes a statement for exact comparison, mirroring
# lib/policy_validation.sh's fingerprint_statement: Action/Resource coerced
# to sorted arrays, Condition sorted at every level (or nil). Two statements
# with the same actions in different order are equal; two that differ only
# in Condition or Resource are not -- unlike a flat action-name check, this
# also catches a policy that grants the right actions on the wrong resource
# or without the right tag-scoping condition.
#
# Must be a lambda bound to a local variable, not a top-level `def`: InSpec
# loads this whole file via instance_eval(source, path) against its own
# internal context object, so a `def` here becomes a singleton method on
# *that* object -- invisible once a `control do...end` block below runs its
# own instance_eval against a distinct Inspec::Rule object. A lambda in a
# local variable is a closure, so it's reachable from anywhere in this
# lexical scope regardless of what `self` is at call time.
fingerprint_statement = lambda do |statement|
  condition = statement["Condition"]
  normalized_condition = condition && condition.each_with_object({}) do |(key, value), acc|
    acc[key] = value.is_a?(Hash) ? value.sort.to_h : value
  end.sort.to_h

  {
    "Effect" => statement["Effect"],
    "Action" => Array(statement["Action"]).sort,
    "Resource" => Array(statement["Resource"]).sort,
    "Condition" => normalized_condition,
  }
end

# Short human label for a statement, mirroring the bash validator's output:
# first action (+N more) -> resource, e.g.
# "elasticloadbalancing:CreateLoadBalancer  (+1 more)  →  *"
label_for_statement = lambda do |statement|
  actions = Array(statement["Action"])
  resources = Array(statement["Resource"])
  resource_label = resources.length == 1 ? resources.first.to_s.sub(/^arn:aws:[^:]*:[^:]*:[^:]*:/, "") : "[#{resources.length} resources]"
  suffix = actions.length > 1 ? "  (+#{actions.length - 1} more)" : ""
  "#{actions.first}#{suffix}  →  #{resource_label}"
end

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
  title "The controller's IAM role actually grants the permissions AWS LBC needs"
  desc "Checking that *a* policy exists and is attached -- even under the " \
       "'right' name -- proves nothing about whether the controller can " \
       "function: a policy called AWSLoadBalancerControllerIAMPolicy that " \
       "actually grants only s3:* would pass a name/existence check while " \
       "leaving the controller inoperable. So this instead fetches the " \
       "same upstream policy document lbc_auth/role.tf and " \
       "install_aws_lbc.sh both install from, applies the same Gateway " \
       "API statement amendment they do, and checks each resulting " \
       "statement -- Effect, Action set, Resource set, and Condition, not " \
       "just the action names -- for an exact match somewhere across " \
       "whatever policies are attached to the discovered role. Mirrors " \
       "scripts/lib/policy_validation.sh's fingerprint_statement so both " \
       "give the same per-statement breakdown."
  impact 1.0

  describe "IAM role discovered from the ServiceAccount binding" do
    subject { role_name.to_s }
    it { should_not be_empty }
  end

  next if role_name.to_s.empty?

  role = aws_iam_role(role_name)

  describe role do
    it { should exist }
  end

  next unless role.exists?

  attached_policy_names = role.attached_policy_names

  describe "IAM policies attached to role #{role_name}" do
    subject { attached_policy_names }
    it { should_not be_empty }
  end

  next if attached_policy_names.empty?

  granted_fingerprints = attached_policy_names.each_with_object(Set.new) do |name, fingerprints|
    policy = aws_iam_policy(policy_name: name)
    next unless policy.exists?
    document = JSON.parse(URI.decode_www_form_component(policy.policy_document.policy_version.document))
    Array(document["Statement"]).each { |statement| fingerprints << fingerprint_statement.call(statement) }
  end

  upstream_document = JSON.parse(Net::HTTP.get(URI(upstream_policy_url)))
  required_statements = Array(upstream_document["Statement"]) + [
    { "Effect" => "Allow", "Action" => gateway_api_actions, "Resource" => "*" },
  ]

  required_statements.each do |statement|
    fp = fingerprint_statement.call(statement)
    label = label_for_statement.call(statement)

    # `it` isn't valid directly inside a `control` block -- InSpec's Rule
    # DSL only exposes `describe` at that level -- so this needs a
    # wrapping describe. RSpec auto-generates an "is expected to include
    # {huge hash}" suffix from the matcher whenever `it` has NO
    # description -- and treats an empty string ("") as "no description",
    # so it still auto-generates even then. A single space is a non-empty
    # string, so it counts as an explicit (if invisible) description and
    # fully suppresses auto-generation, leaving `describe label`'s own
    # text as the whole visible line.
    describe label do
      it(" ") { expect(granted_fingerprints).to include(fp) }
    end
  end
end
