variable "k8s_name" {
  type        = string
  description = "Display name for the k8s cluster"
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

variable "k8s_argo_autoupdate" {
  type        = bool
  description = "Configure argo to use bleeding edge version of app bundles, not considered stable as there may be active development"
  default     = false
}

variable "k8s_ingress_rootdomain" {
  type        = string
  description = "Specify a root domain for any relevant apps. Leave empty to disable or if one is not available."
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


locals {
  argo-examples = {
    common = {
      ingress = {
        enabled    = length(trimspace(var.k8s_ingress_rootdomain)) > 0
        rootDomain = var.k8s_ingress_rootdomain
      }
    }
  }
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
    argo-cd = {
      order           = 30
      wait            = true
      repository_name = "argocd"
      repository_url  = "https://argoproj.github.io/argo-helm"
      chart           = "argo-cd"
      version         = "7.7.14"
      namespace       = "argocd"
      config = {
        configs = {
          "cm" = {
            "resource.customizations.health.argoproj.io_Application" = <<-EOT
              hs = {}
              hs.status = "Progressing"
              hs.message = ""
              if obj.status ~= nil then
                if obj.status.health ~= nil then
                  hs.status = obj.status.health.status
                  if obj.status.health.message ~= nil then
                    hs.message = obj.status.health.message
                  end
                end
              end
              return hs
              EOT
          }
        }
      }
    }
    argo-examples-operators = {
      enabled         = !var.k8s_argo_autoupdate
      order           = 31
      wait            = true
      repository_name = "eric-zadara"
      repository_url  = "https://eric-zadara.github.io/helm_charts"
      #repository_name = "zadarastorage"
      #repository_url  = "https://zadarastorage.github.io/helm-charts"
      chart     = "argo-examples-operators"
      version   = "0.0.14"
      namespace = "argo-examples"
      config    = local.argo-examples
    }
    argo-examples-onyx = {
      enabled         = !var.k8s_argo_autoupdate
      order           = 32
      wait            = true
      repository_name = "eric-zadara"
      repository_url  = "https://eric-zadara.github.io/helm_charts"
      #repository_name = "zadarastorage"
      #repository_url  = "https://zadarastorage.github.io/helm-charts"
      chart     = "argo-examples-onyx"
      version   = "0.0.36"
      namespace = "argo-examples"
      config    = local.argo-examples
    }
    argo-apps = {
      enabled         = var.k8s_argo_autoupdate
      order           = 91
      wait            = true
      repository_name = "argocd"
      repository_url  = "https://argoproj.github.io/argo-helm"
      chart           = "argocd-apps"
      version         = "2.0.2"
      namespace       = "argo-apps"
      config = {
        "applications" = {
          "argo-examples-operators" = {
            "additionalAnnotations" = { "argocd.argoproj.io/sync-wave" = "1" }
            "destination" = {
              "namespace" = "argo-examples"
              "server"    = "https://kubernetes.default.svc"
            }
            "namespace" = "argocd"
            "project"   = "default"
            "source" = {
              "helm" = {
                "valuesObject" = local.argo-examples
              }
              "path"           = "charts/argo-examples-operators"
              "repoURL"        = "https://github.com/eric-zadara/helm_charts.git"
              "targetRevision" = "HEAD"
            }
            "syncPolicy" = {
              "automated" = {
                "prune"    = true
                "selfHeal" = true
              }
              "syncOptions" = [
                "CreateNamespace=true",
              ]
            }
          }
          "argo-examples-onyx" = {
            "additionalAnnotations" = { "argocd.argoproj.io/sync-wave" = "2" }
            "destination" = {
              "namespace" = "argo-examples"
              "server"    = "https://kubernetes.default.svc"
            }
            "namespace" = "argocd"
            "project"   = "default"
            "source" = {
              "helm" = {
                "valuesObject" = local.argo-examples
              }
              "path"           = "charts/argo-examples-onyx"
              "repoURL"        = "https://github.com/eric-zadara/helm_charts.git"
              "targetRevision" = "HEAD"
            }
            "syncPolicy" = {
              "automated" = {
                "prune"    = true
                "selfHeal" = true
              }
              "syncOptions" = [
                "CreateNamespace=true",
              ]
            }
          }
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
      instance_type    = "A02.4xLarge" # TODO Adjust to formalized instance_type name
      root_volume_size = 200
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
