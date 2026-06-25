# Create the IAM Policy
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = data.http.aws_load_balancer_controller_iam_policy.response_body
}

# Create the IAM Role and attach the policy
resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.eks_cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
