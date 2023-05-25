# Region Credentials
variable "zCompute_ip" {}
variable "secret_key" {}
variable "access_key" {}
variable "credentials_file" {
  default = "~/.aws/credentials"
}

variable "lb_type" {
  default = "application"
}
variable "protocol" {
  default = "HTTP"
}


# Main variables
variable "ami_webserver" {}
variable "web_servers_number" {
  default = 2
}
variable "web_servers_type" {
  default = "t2.small"
}
