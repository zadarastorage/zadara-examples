data "cloudinit_config" "root-ca-trust-config" {
  gzip          = true
  base64_encode = true
  count         = var.root_ca_cert_path != "" ? 1 : 0
  part {
    content_type = "text/cloud-config"
    content = <<-EOF
      #cloud-config
      ${yamlencode({
    ca_certs = {
      trusted = [
        file(var.root_ca_cert_path)
      ]
    }
})}
    EOF
}
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  vpc      = true

  depends_on = [aws_vpc.eksd_vpc, aws_subnet.eksd_public, aws_subnet.eksd_private]
}

resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami
  instance_type          = var.bastion_instance_type
  key_name               = var.bastion_keyname
  subnet_id              = aws_subnet.eksd_public.id
  vpc_security_group_ids = [aws_security_group.eksd_bastion_sg.id]
  user_data              = var.root_ca_cert_path != "" ? data.cloudinit_config.root-ca-trust-config[0].rendered : null

  tags = {
    Name = "bastion"
  }
  depends_on = [aws_route.igw, aws_route_table_association.public_to_public]
}
