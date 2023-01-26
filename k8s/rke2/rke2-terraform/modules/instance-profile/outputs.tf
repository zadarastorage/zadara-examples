output "instance_profile_name" {
  description = "In 22.09.x the launch configuration expecting the unique id and not the instance profile name."
  value = aws_iam_instance_profile.profile.unique_id
}