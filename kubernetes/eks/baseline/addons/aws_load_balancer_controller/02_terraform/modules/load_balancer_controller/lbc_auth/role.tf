# Fetch the AWS-managed policy document directly
data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
}

locals {
  # The upstream policy doesn't cover the ELBv2 listener-attributes API,
  # which AWS LBC needs for Gateway API support (ALBGatewayAPI/NLBGatewayAPI/
  # GatewayListenerSet -- see values.yaml.tmpl in ../lbc_install). Mirrors
  # the jq amendment create_lbc_iam_policy() applies in
  # ../../../../install_aws_lbc.sh.
  aws_load_balancer_controller_base_policy = jsondecode(data.http.aws_load_balancer_controller_iam_policy.response_body)

  aws_load_balancer_controller_policy = jsonencode(merge(
    local.aws_load_balancer_controller_base_policy,
    {
      Statement = concat(local.aws_load_balancer_controller_base_policy.Statement, [
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:DescribeListenerAttributes",
            "elasticloadbalancing:ModifyListenerAttributes",
          ]
          Resource = "*"
        },
      ])
    }
  ))

  # Same role/policy names regardless of auth_mode -- a given root only ever
  # runs one mode, and separate deployments (different clusters, different
  # environments) are already segregated by separate Terraform state
  # (different roots / workspaces / tfvars), not by baking a mode suffix
  # into the resource name. Callers that do need a non-default name (e.g.
  # to run more than one instance of this module against the same account)
  # can set var.role_name / var.policy_name explicitly.
  role_name   = coalesce(var.role_name, "${var.eks_cluster_name}-aws-load-balancer-controller")
  policy_name = coalesce(var.policy_name, "AWSLoadBalancerControllerIAMPolicy")

  # Whichever mode is active supplies the trust policy (see irsa.tf/podid.tf)
  assume_role_policy = var.auth_mode == "irsa" ? data.aws_iam_policy_document.irsa_assume_role[0].json : data.aws_iam_policy_document.podid_assume_role[0].json
}

# Create the IAM Policy
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = local.policy_name
  path        = "/"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = local.aws_load_balancer_controller_policy
}

# Create the IAM Role and attach the policy
resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = local.role_name
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
