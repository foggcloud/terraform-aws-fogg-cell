locals {
  name = format("%s-%s", var.name, terraform.workspace)
}

data "aws_ami" "this" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix = format("%s-", local.name)

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  image_id  = data.aws_ami.this.id
  key_name  = var.key_name
  user_data = base64encode(templatefile("user_data.sh.tmpl", { cluster = var.cluster, zerotier_network = var.zerotier_network }))

  vpc_security_group_ids = [aws_security_group.this.id]
}

resource "aws_autoscaling_group" "this" {
  name_prefix = format("%s-", local.name)

  vpc_zone_identifier   = [var.subnet_id]
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  protect_from_scale_in = false

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [min_size, max_size, desired_capacity]
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "this" {
  name   = local.name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "zerotier" {
  type              = "ingress"
  from_port         = 9993
  to_port           = 9993
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "zerotier_ipv6" {
  type              = "ingress"
  from_port         = 9993
  to_port           = 9993
  protocol          = "udp"
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "egress_ipv6" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.this.id
}

resource "aws_iam_instance_profile" "this" {
  name = local.name
  role = aws_iam_role.this.name
}

resource "aws_iam_role" "this" {
  name = local.name

  assume_role_policy    = data.aws_iam_policy_document.assume.json
  force_detach_policies = true
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ec2_AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_AmazonEC2ContainerServiceforEC2Role" {
  role       = aws_iam_role.this.id
  policy_arn = aws_iam_policy.ec2_AmazonEC2ContainerServiceforEC2Role.arn
}

resource "aws_iam_policy" "ec2_AmazonEC2ContainerServiceforEC2Role" {
  name   = format("%s-%s", local.name, "ecs")
  policy = data.aws_iam_policy_document.ec2_AmazonEC2ContainerServiceforEC2Role.json
}

data "aws_iam_policy_document" "ec2_AmazonEC2ContainerServiceforEC2Role" {
  statement {
    actions = [
      "ec2:DescribeTags",
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "*",
    ]
  }
}
