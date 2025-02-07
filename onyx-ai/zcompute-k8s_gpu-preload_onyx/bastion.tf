variable "bastion_enabled" {
  type        = bool
  description = "Enable bastion jumphost"
}

variable "bastion_ssh_source_cidr" {
  type        = string
  description = "(No-effect if bastion is disabled) CIDR to restrict inbound SSH access of bastion host to. ex: 0.0.0.0/0 or 8.8.8.8/32"
}

locals {
  ami_options = [
    {
      codename = "noble"
      year     = 2024
      regex    = "Public - Ubuntu Server 24.04"
    },
    {
      codename = "jammy"
      year     = 2022
      regex    = "Public - Ubuntu Server 22.04"
    },
    {
      codename = "focal"
      year     = 2020
      regex    = "Public - Ubuntu Server 20.04"
    },
    {
      codename = "bionic"
      year     = 2018
      regex    = "Public - Ubuntu Server 18.04"
    },
  ]
  bastion_security_group_rules = {
    ingress_ipv4_ssh = {
      description = "Allow all inbound ssh"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [var.bastion_ssh_source_cidr]
    }
    egress_ipv4 = {
      description = "Allow all outbound"
      protocol    = "all"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

}

data "aws_ami_ids" "bastion_ubuntu" {
  count      = length(local.ami_options)
  owners     = ["*"]
  name_regex = "^${local.ami_options[count.index].regex}$"

  filter {
    name   = "is-public"
    values = ["true"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "bastion" {
  count       = try(var.bastion_enabled, false) ? 1 : 0
  name        = "${var.k8s_name}_bastion"
  description = "Bastion public traffic"
  vpc_id      = module.vpc.vpc_id

  #tags = merge(local.tags, {})
}

resource "aws_security_group_rule" "bastion" {
  for_each         = try(var.bastion_enabled, false) ? local.bastion_security_group_rules : {}
  type             = try(each.value.type, null)
  description      = try(each.value.description, null)
  from_port        = try(each.value.from_port, null)
  to_port          = try(each.value.to_port, null)
  protocol         = try(each.value.protocol, null)
  self             = try(each.value.self, null)
  cidr_blocks      = try(each.value.cidr_blocks, null)
  ipv6_cidr_blocks = try(each.value.ipv6_cidr_blocks, null)

  security_group_id = aws_security_group.bastion[0].id
}

resource "aws_instance" "bastion" {
  count = try(var.bastion_enabled, false) ? 1 : 0

  instance_type = "z2.large"
  ami           = flatten(data.aws_ami_ids.bastion_ubuntu[*].ids)[0]
  key_name      = aws_key_pair.this.key_name

  tags = { Name = "${var.k8s_name}-bastion" }

  subnet_id = one(module.vpc.public_subnets)

  vpc_security_group_ids = [aws_security_group.bastion[0].id, module.k8s.cluster_security_group_id, ]

  root_block_device {
    volume_size           = 32
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [
      ami,
      tags["os_family_linux"]
    ]
  }
}

resource "aws_eip" "bastion" {
  count    = try(var.bastion_enabled, false) ? 1 : 0
  instance = aws_instance.bastion[0].id
  vpc      = true
}
