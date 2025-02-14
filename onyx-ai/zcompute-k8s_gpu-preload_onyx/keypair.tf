variable "keypair_name" {
  type        = string
  description = "Display name for user's ssh key"
}

variable "keypair_publickey" {
  type        = string
  description = "Contents of the user's public ssh keyfile. Ex: ssh-rsa AAB3Nze..."
}

resource "aws_key_pair" "this" {
  key_name   = var.keypair_name
  public_key = var.keypair_publickey
}
