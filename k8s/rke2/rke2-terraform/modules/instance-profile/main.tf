resource "aws_iam_instance_profile" "profile" {
  role = aws_iam_role.role.name
  name = var.name
}

resource "aws_iam_role" "role" {
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
  name        = "${var.iam_role_name}-policy"
  description = "Policy for iam role ${var.iam_role_name}"
  policy = var.iam_policy
}

resource "aws_iam_policy_attachment" "test-attach" {
  name       = "${var.iam_role_name}-policy-attachment"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.policy.arn
}