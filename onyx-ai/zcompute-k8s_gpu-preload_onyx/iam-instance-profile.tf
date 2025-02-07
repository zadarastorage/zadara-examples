module "iam-instance-profile" {
  source = "github.com/zadarastorage/terraform-zcompute-iam-instance-profile?ref=main"
  # It's recommended to change `main` to a specific release version to prevent unexpected changes

  name                  = "k8s-instance-profile"
  instance_profile_path = "/"

  use_existing_role   = false
  use_existing_policy = false

  role_name = "k8s-role"
  role_path = "/"

  policy_name = "k8s-policy"
  policy_path = "/"
  policy_contents = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "elasticloadbalancing:*",
          "ec2:*",
        ]
        Resource = ["*"]
      },
    ]
  }

}
