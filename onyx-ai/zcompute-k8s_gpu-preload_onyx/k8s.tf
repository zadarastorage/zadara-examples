variable "k8s_name" {
  type        = string
  description = "Display name for the k8s cluster. (Only alphanumeric characters and hyphen)"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.k8s_name))
    error_message = "The value for 'k8s_name' must contain only alphanumeric characters and hyphens."
  }
}

variable "k8s_version" {
  type        = string
  description = "Version of k8s to use"
  default     = "1.31.2"
}

# Object storage backup configuration
variable "k8s_etcd_s3_endpoint" {
  type        = string
  description = "ETCD Backup: S3 Compatible endpoint domain(NOT A URL!). ex: vsa-000000xx-public-xyz.zadarazios.com"
}
variable "k8s_etcd_s3_access_key" {
  type        = string
  description = "ETCD Backup: S3 Compatible Access Key"
}
variable "k8s_etcd_s3_secret_key" {
  type        = string
  description = "ETCD Backup: S3 Compatible Secret Key"
  sensitive   = true
}
variable "k8s_etcd_s3_bucket" {
  type        = string
  description = "ETCD Backup: S3 Compatible Bucket"
}
variable "k8s_etcd_s3_region" {
  type        = string
  description = "ETCD Backup: S3 Compatible Region"
}
variable "k8s_etcd_s3_folder" {
  type        = string
  description = "ETCD Backup: Path Prefix"
}
variable "k8s_etcd_snapshot_retention" {
  type        = number
  description = "ETCD Backup: Snapshot count retention"
  # k3s retention is configured on all control plane VMs, but k3s implementation does not account for parallel backup execution. So 3 snapshots per cycle will still remove 3 oldest snapshots regardless of which control plane VM created it.
  # 168 = 28 days * 2 a day * 3 VMs.
  default = 168
}

module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s?ref=main"
  # It's recommended to change `main` to a specific release version to prevent unexpected changes

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  tags = var.tags

  etcd_backup = {
    s3                 = true
    s3-endpoint        = var.k8s_etcd_s3_endpoint
    s3-access-key      = var.k8s_etcd_s3_access_key
    s3-secret-key      = var.k8s_etcd_s3_secret_key
    s3-bucket          = var.k8s_etcd_s3_bucket
    s3-region          = var.k8s_etcd_s3_region
    s3-folder          = var.k8s_etcd_s3_folder
    snapshot-retention = var.k8s_etcd_snapshot_retention
  }

  cluster_name    = var.k8s_name
  cluster_version = var.k8s_version
  cluster_helm = {
    gpu-operator = {
      order           = 30
      wait            = true
      repository_name = "nvidia"
      repository_url  = "https://helm.ngc.nvidia.com/nvidia"
      chart           = "gpu-operator"
      version         = "v24.6.1"
      namespace       = "gpu-operator"
      config = {
        driver = {
          enabled   = true
          resources = { requests = { cpu = "0.01", memory : "6Gi" } }
        }
        toolkit = { enabled = true }
        devicePlugin = {
          config = {
            create  = true
            name    = "device-plugin-configs"
            default = "any"
            data = {
              # Tesla A16
              tesla-25b6 = yamlencode({
                version = "v1"
                flags   = { migStrategy = "none" }
                sharing = { timeSlicing = {
                  failRequestsGreaterThanOne = false
                  resources                  = [{ name = "nvidia.com/gpu", replicas = 17 }]
                } }
              })
              # Tesla A40
              tesla-2235 = yamlencode({
                version = "v1"
                flags   = { migStrategy = "none" }
                sharing = { timeSlicing = {
                  failRequestsGreaterThanOne = false
                  resources                  = [{ name = "nvidia.com/gpu", replicas = 49 }]
                } }
              })
              # Tesla L4
              tesla-27b8 = yamlencode({
                version = "v1"
                flags   = { migStrategy = "none" }
                sharing = { timeSlicing = {
                  failRequestsGreaterThanOne = false
                  resources                  = [{ name = "nvidia.com/gpu", replicas = 25 }]
                } }
              })
              # Tesla L40S
              tesla-26b9 = yamlencode({
                version = "v1"
                flags   = { migStrategy = "none" }
                sharing = { timeSlicing = {
                  failRequestsGreaterThanOne = false
                  resources                  = [{ name = "nvidia.com/gpu", replicas = 49 }]
                } }
              })
            }
          }
        }
        nfd = { enabled = true }
        node-feature-discovery = {
          worker = {
            config = {
              sources = {
                custom = [{
                  name           = "gpu-timeslice"
                  labelsTemplate = "{{ range .pci.device }}nvidia.com/device-plugin.config=tesla-{{ .device }}{{ end }}"
                  matchFeatures = [{
                    feature = "pci.device"
                    matchExpressions = {
                      class  = { op = "InRegexp", value = ["^03"] }
                      vendor = ["10de"]
                    }
                  }]
                }]
              }
            }
          }
        }
      }
    }
    cert-manager = {
      order           = 31
      wait            = true
      repository_name = "cert-manager"
      repository_url  = "https://charts.jetstack.io"
      chart           = "cert-manager"
      version         = "v1.15.3"
      namespace       = "cert-manager"
      config          = { crds = { enabled = true } }
    }
    cert-manager-clusterissuers = {
      order           = 32
      wait            = false
      repository_name = "eric-zadara"
      repository_url  = "https://eric-zadara.github.io/helm_charts"
      chart           = "cert-manager-clusterissuers"
      version         = "0.0.1"
      namespace       = "cert-manager"
      config          = { selfSigned = { enabled = true } }
    }
    cloudnative-pg = {
      order           = 31
      wait            = true
      repository_name = "cloudnative-pg"
      repository_url  = "https://cloudnative-pg.io/charts/"
      chart           = "cloudnative-pg"
      version         = "0.22.0"
      namespace       = "cloudnative-pg"
      config          = null
    }
    ollama = {
      order           = 34
      wait            = false
      repository_name = "ollama-helm"
      repository_url  = "https://otwld.github.io/ollama-helm/"
      chart           = "ollama"
      version         = "1.24.0"
      namespace       = "ollama"
      config = {
        ollama = {
          gpu    = { enabled = true, type = "nvidia" }
          models = { pull = ["llama3.1:8b-instruct-q8_0"], run = ["llama3.1:8b-instruct-q8_0"] }
        }
        replicaCount = 1
        extraEnv = [{
          name  = "OLLAMA_KEEP_ALIVE"
          value = "-1"
        }]
        resources = {
          requests = { cpu = "4", memory = "15Gi", "nvidia.com/gpu" = "8" }
          limits   = { cpu = "8", memory = "20Gi", "nvidia.com/gpu" = "8" }
        }
        persistentVolume = { enabled = true, size = "200Gi" }
        runtimeClassName = "nvidia"
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [
                {
                  matchExpressions = [{
                    key      = "nvidia.com/device-plugin.config"
                    operator = "In"
                    values   = ["tesla-25b6", "tesla-2235", "tesla-27b8", "tesla-26b9"]
                  }]
                }
              ]
            }
          }
        }
      }
    }
    onyx = {
      order           = 35
      wait            = false
      repository_name = "zadarastorage"
      repository_url  = "https://zadarastorage.github.io/helm-charts"
      chart           = "onyx"
      version         = "0.0.23"
      namespace       = "onyx"
      config = {
        inference = {
          tolerations      = [{ effect = "NoSchedule", operator = "Exists", key = "nvidia.com/gpu" }]
          runtimeClassName = "nvidia"
          affinity = { nodeAffinity = { requiredDuringSchedulingIgnoredDuringExecution = { nodeSelectorTerms = [
            { matchExpressions = [{
              key      = "nvidia.com/device-plugin.config"
              operator = "In"
              values   = ["tesla-25b6", "tesla-2235", "tesla-27b8", "tesla-26b9"]
              }]
          }] } } }
          resources = {
            requests = { "nvidia.com/gpu" = "4" }
            limits   = { "nvidia.com/gpu" = "4" }
          }
        }
        index = {
          tolerations      = [{ effect = "NoSchedule", operator = "Exists", key = "nvidia.com/gpu" }]
          runtimeClassName = "nvidia"
          affinity = { nodeAffinity = { requiredDuringSchedulingIgnoredDuringExecution = { nodeSelectorTerms = [
            { matchExpressions = [{
              key      = "nvidia.com/device-plugin.config"
              operator = "In"
              values   = ["tesla-25b6", "tesla-2235", "tesla-27b8", "tesla-26b9"]
              }]
          }] } } }
          resources = {
            requests = { "nvidia.com/gpu" = "4" }
            limits   = { "nvidia.com/gpu" = "4" }
          }
        }
        ingress = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer"                   = "selfsigned"
            "traefik.ingress.kubernetes.io/router.entrypoints" = "web,websecure"
          }
          tls = true
        }
        cnpg = {
          cluster = { instances = 1, monitoring = { enabled = false } }
          pooler  = { instances = 1, monitoring = { enabled = false } }
        }
      }
    }
  }

  node_group_defaults = {
    root_volume_size     = 64
    cluster_flavor       = "k3s-ubuntu"
    iam_instance_profile = module.iam-instance-profile.instance_profile_name
    security_group_rules = {
      egress_ipv4 = {
        description = "Allow all outbound ipv4 traffic"
        protocol    = "all"
        from_port   = 0
        to_port     = 65535
        type        = "egress"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
    key_name = aws_key_pair.this.key_name
    cloudinit_config = [
      {
        order        = 5
        filename     = "cloud-config-registry.yaml"
        content_type = "text/cloud-config"
        content = join("\n", ["#cloud-config", yamlencode({ write_files = [
          { path = "/etc/rancher/k3s/registries.yaml", owner = "root:root", permissions = "0640", encoding = "b64", content = base64encode(yamlencode({
            configs = {}
            mirrors = {
              "*" = {}
              "docker.io" = {
                endpoint = ["https://mirror.gcr.io"]
              }
            }
          })) },
        ] })])
      },
    ]
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
    worker = {
      role          = "worker"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      instance_type = "z8.3xlarge"
    }
    gpu = {
      role             = "worker"
      min_size         = 0
      max_size         = 3
      desired_size     = 1
      root_volume_size = 200
      instance_type    = "A02.4xLarge" # TODO Adjust to formalized instance_type name
      k8s_taints = {
        "nvidia.com/gpu" = "true:NoSchedule"
      }
      k8s_labels = {
        "tesla-a16"                       = "true"
        "nvidia.com/gpu"                  = "true"
        "nvidia.com/device-plugin.config" = "tesla-25b6"
        "nvidia.com/gpu.deploy.driver"    = "false"
      }
      tags = {
        "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu" = "17"
        "nvidia.com/device-plugin.config"                                  = "tesla-25b6"
      }
      cloudinit_config = [
        {
          order        = 11
          filename     = "setup-gpu.sh"
          content_type = "text/x-shellscript"
          content      = file("${path.module}/files/setup-gpu.sh")
        }
      ]
    }
  }
}
