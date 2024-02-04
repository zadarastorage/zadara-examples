# zCompute API
api_endpoint = ""

# Bastion
ssh_bastion_username = "ubuntu"
bastion_public_ip    = ""

# Packer build
ami_id               = "ami-..."
ssh_username         = "ubuntu"
subnet_id            = "subnet-..."
ssh_keypair_name     = "packer"
private_keypair_path = "~/.ssh/bastion.pem"

eksd_k8s_version     = "1-29"
eksd_revision        = "3"
