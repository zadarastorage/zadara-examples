resource "aws_iam_instance_profile" "profile" {
  role = var.iam_role_name
  name = var.name
}

resource "aws_iam_role" "role" {
  count = var.existing_role ? 0 : 1
  name = var.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "policy" {
  count = var.existing_role ? 0 : 1
  name        = "${var.iam_role_name}-policy"
  description = "Policy for iam role ${var.iam_role_name}"
  policy = var.iam_policy
}

resource "aws_iam_policy_attachment" "test-attach" {
  count      = var.existing_role ? 0 : 1
  name       = "${var.iam_role_name}-policy-attachment"
  roles      = [aws_iam_role.role[count.index].name]
  policy_arn = aws_iam_policy.policy[count.index].arn
}