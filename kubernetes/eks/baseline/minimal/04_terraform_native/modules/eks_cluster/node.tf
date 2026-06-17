###################
# Node Group
##############################
resource "aws_launch_template" "ng_1" {
  name_prefix = "${var.eks_cluster_name}-ng-1-"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 80
      volume_type = "gp3"
      iops        = 3000
      throughput  = 125
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                             = "${var.eks_cluster_name}-ng-1-Node"
      "alpha.eksctl.io/nodegroup-name" = "ng-1"
      "alpha.eksctl.io/nodegroup-type" = "managed"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name                             = "${var.eks_cluster_name}-ng-1-Node"
      "alpha.eksctl.io/nodegroup-name" = "ng-1"
      "alpha.eksctl.io/nodegroup-type" = "managed"
    }
  }

  tag_specifications {
    resource_type = "network-interface"

    tags = {
      Name                             = "${var.eks_cluster_name}-ng-1-Node"
      "alpha.eksctl.io/nodegroup-name" = "ng-1"
      "alpha.eksctl.io/nodegroup-type" = "managed"
    }
  }
}

resource "aws_iam_role" "node" {
  name = "${var.eks_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_pull_only" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_node_group" "ng_1" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-1"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = values(var.private_subnet_ids)

  instance_types = ["m5.large"]

  launch_template {
    id      = aws_launch_template.ng_1.id
    version = aws_launch_template.ng_1.latest_version
  }

  labels = {
    "alpha.eksctl.io/cluster-name"   = var.eks_cluster_name
    "alpha.eksctl.io/nodegroup-name" = "ng-1"
  }

  tags = {
    "alpha.eksctl.io/nodegroup-name" = "ng-1"
    "alpha.eksctl.io/nodegroup-type" = "managed"
  }

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 3
  }

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr_pull_only,
    aws_iam_role_policy_attachment.node_ssm
  ]
}

