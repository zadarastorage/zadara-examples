variable "tags" {
  type        = map(string)
  description = "Tags to be attached to all capable objects"
  default     = { my-tag = "my-value" }
}

