resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  vpc      = true

  depends_on = [aws_vpc.rke2_vpc, aws_subnet.rke2_public, aws_subnet.rke2_private]
}

resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami
  instance_type          = var.bastion_instance_type
  key_name               = var.bastion_key_name
  subnet_id              = aws_subnet.rke2_public.id
  vpc_security_group_ids = [aws_security_group.rke2_k8s.id]
  tags                   = {
    Name = "bastion"
  }
}