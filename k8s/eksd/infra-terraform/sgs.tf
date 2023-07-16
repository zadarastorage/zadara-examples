resource "aws_default_security_group" "eksd" {
  vpc_id = aws_vpc.eksd_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-eksd-default-sg"
  }
}

resource "aws_security_group_rule" "eksd_default_sg_egress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_default_security_group.eksd.id
  security_group_id        = aws_default_security_group.eksd.id
  type                     = "egress"
}

resource "aws_security_group_rule" "eksd_default_sg_ingress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_default_security_group.eksd.id
  security_group_id        = aws_default_security_group.eksd.id
  type                     = "ingress"
}

resource "aws_security_group" "eksd_k8s" {
  vpc_id = aws_vpc.eksd_vpc.id
  name = "${var.environment}-vpc-eksd-k8s"
}

resource "aws_security_group_rule" "eksd_k8s_sg_egress" {
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eksd_k8s.id
  type              = "egress"
}

resource "aws_security_group_rule" "eksd_k8s_sg_ingress" {
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eksd_k8s.id
  security_group_id        = aws_security_group.eksd_k8s.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "eksd_k8s_sg_ssh_ingress" {
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eksd_k8s.id
  type              = "ingress"
}

resource "aws_security_group_rule" "eksd_k8s_api_public" {
  count             = var.expose_k8s_api_publicly ? 1 : 0
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eksd_k8s.id
  type              = "ingress"
}

resource "aws_security_group_rule" "eksd_k8s_api_private" {
  count             = var.expose_k8s_api_publicly ? 0 : 1
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eksd_k8s.id
  security_group_id = aws_security_group.eksd_k8s.id
  type              = "ingress"
}