output "instance_ids" {
  value = aws_instance.group-instances.*.id
}

output "group_name" {
  value = var.group_name
}

output "current_asg_desired_count" {
  value = local.existing_asg_desired_capacity
}