variable "name" {
  description = "Name of instance profile to create"
  type = string
}

variable "iam_role_name" {
  description = "Instance profile IAM role name"
  type = string
}

variable "iam_policy" {
  description = "(Required) The instance profile iam role policy document. This is a JSON formatted string. For more information about building AWS IAM policy documents with Terraform, see the AWS IAM Policy Document Guide"
  type = string
}

variable "iam_role_session_duration" {
  description = "IAM Role maximal session duration (in seconds, defaulting to 12 hours)"
  type = number
  default = 43200
}

variable "use_existing_role" {
  description = "Use existing IAM role"
  type = bool
  default = false
}