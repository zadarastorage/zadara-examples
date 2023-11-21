#cloud-config
ssh_authorized_keys:
  - ${ public_key_content }
hostname: rke

