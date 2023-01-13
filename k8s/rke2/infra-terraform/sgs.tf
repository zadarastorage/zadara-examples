resource "aws_default_security_group" "rke2" {
  vpc_id = aws_vpc.rke2_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-rke2-default-sg"
  }
}

resource "aws_security_group_rule" "rke2_default_sg_egress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_default_security_group.rke2.id
  security_group_id        = aws_default_security_group.rke2.id
  type                     = "egress"
}

resource "aws_security_group_rule" "rke2_default_sg_ingress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_default_security_group.rke2.id
  security_group_id        = aws_default_security_group.rke2.id
  type                     = "ingress"
}

resource "aws_security_group" "rke2_k8s" {
  vpc_id = aws_vpc.rke2_vpc.id
  name = "${var.environment}-vpc-rke2-k8s"
}

resource "aws_security_group_rule" "rke2_k8s_sg_egress" {
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rke2_k8s.id
  type              = "egress"
}

resource "aws_security_group_rule" "rke2_k8s_sg_ingress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.rke2_k8s.id
  security_group_id        = aws_security_group.rke2_k8s.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "rke2_k8s_sg_ssh_ingress" {
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rke2_k8s.id
  type              = "ingress"
}

resource "aws_security_group_rule" "rke2_k8s_api_public" {
  count             = var.expose_k8s_api_publicly ? 1 : 0
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rke2_k8s.id
  type              = "ingress"
}

resource "aws_security_group_rule" "rke2_k8s_api_private" {
  count             = var.expose_k8s_api_publicly ? 0 : 1
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  source_security_group_id = aws_security_group.rke2_k8s.id
  security_group_id = aws_security_group.rke2_k8s.id
  type              = "ingress"
}