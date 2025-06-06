# Copyright (c) 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  cilium_helm_crds_file            = join("/", [local.yaml_manifest_path, "cilium.crds.yaml"])
  cilium_helm_manifest_file        = join("/", [local.yaml_manifest_path, "cilium.manifest.yaml"])
  cilium_helm_values_file          = join("/", [local.yaml_manifest_path, "cilium.values.yaml"])
  cilium_helm_values_override_file = join("/", [local.yaml_manifest_path, "cilium.values-override.yaml"])
  cilium_net_attach_def_file       = join("/", [local.yaml_manifest_path, "cilium.net_attach_def.yaml"])
  cilium_veth_config_map_file      = join("/", [local.yaml_manifest_path, "cilium.cni_config_map.yaml"])

  cilium_helm_crds            = one(data.helm_template.cilium[*].crds)
  cilium_helm_values_override = one(data.helm_template.cilium[*].values)
  
  cilium_helm_repository      = "https://helm.cilium.io"

  cilium_vxlan_cni = {
    install      = true
    exclusive    = true # !var.multus_install
  }

  cilium_helm_values = {
    annotateK8sNode                 = true
    cluster                         = {
      name = "oke-${var.state_id}"
      id   = 1
    }
    clustermesh                     = { 
      useAPIServer = false 
      apiserver = {
        kvstoremesh = {
          enabled = false
        }
      }
    }
    cni                             = local.cilium_vxlan_cni
    installNoConntrackIptablesRules = false
    ipam                            = { mode = "kubernetes" }
    kubeProxyReplacement            = false
    k8sServiceHost                  = var.cluster_private_endpoint
    k8sServicePort                  = "6443"
    pmtuDiscovery                   = { enabled = true }
    rollOutCiliumPods               = true
    tunnelProtocol                  = local.cilium_tunnel
    
    hubble = {
      metrics = {
        dashboards = { enabled = var.prometheus_install }
        # serviceMonitor = { enabled = var.prometheus_enabled }
      }
      relay = { enabled = true }
      ui    = { enabled = true }
    }

    k8s = {
      requireIPv4PodCIDR   = true # wait for Kubernetes to provide the PodCIDR (ipam kubernetes)
    }

    # Prometheus metrics

    operator = {
      prometheus = {
        enabled = var.prometheus_install
        # serviceMonitor = { enabled = var.prometheus_enabled }
      }
    }
  }

 # TODO Support Flannel w/ generic-veth & tunnel disabled
  cilium_tunnel = "vxlan" # var.cni_type == "flannel" ? "disabled" : "vxlan"

  cilium_flannel_cni = {
    install      = true
    chainingMode = "generic-veth"
    configMap    = "cni-configuration"
    customConf   = var.cni_type == "flannel"
    exclusive    = !var.multus_install
  }
  
  cilium_net_attach_def_conf = {
    cniVersion = "0.3.1"
    name       = "cilium"
    plugins = [
      {
        cniVersion = "0.3.1"
        name       = "cilium"
        type       = "cilium-cni"
      },
      {
        name = "cilium-sbr"
        type = "sbr"
      }
    ],
  }

  cilium_net_attach_def = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata   = { name = "cilium" }
    spec       = { config = jsonencode(local.cilium_net_attach_def_conf) }
  }

  cilium_veth_conf = {
    cniVersion = "0.3.1"
    name       = "cbr0"
    "plugins" = [
      {
        type = "flannel"
        delegate = {
          hairpinMode      = true
          isDefaultGateway = true
        }
      },
      {
        type         = "portmap"
        capabilities = { portMappings = true }
      },
      { type = "cilium-cni" },
    ]
  }

  cilium_veth_config_map = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "cni-configuration"
      namespace = var.cilium_namespace
    }
    data = { "cni-config" = jsonencode(local.cilium_veth_conf) }
  }

  cilium_net_attach_def_yaml       = yamlencode(local.cilium_net_attach_def)
  cilium_veth_config_map_yaml      = yamlencode(local.cilium_veth_config_map)
  cilium_helm_values_yaml          = yamlencode(merge(local.cilium_helm_values, var.cilium_helm_values))
  cilium_helm_values_override_yaml = local.cilium_helm_values_override != null ? join("\n", local.cilium_helm_values_override) : ""
}

data "helm_template" "cilium" {
  count        = var.cilium_install ? 1 : 0
  chart        = "cilium"
  repository   = local.cilium_helm_repository
  version      = var.cilium_helm_version
  kube_version = var.kubernetes_version

  name             = "cilium"
  namespace        = var.cilium_namespace
  create_namespace = true
  include_crds     = true
  skip_tests       = true
  values = concat(
    [local.cilium_helm_values_yaml],
    [for path in var.cilium_helm_values_files : file(path)],
  )

  lifecycle {
    precondition {
      condition = alltrue([for path in var.cilium_helm_values_files : fileexists(path)])
      error_message = format("Missing Helm values files in configuration: %s",
        jsonencode([for path in var.cilium_helm_values_files : path if !fileexists(path)])
      )
    }
  }
}

variable "remote_host_ip" {
  type        = string
  description = "IP of the host to run remote-exec commands from (operator VM)."
}

variable "remote_host_user" {
  type        = string
  description = "SSH user for the remote_host_ip."
}

variable "remote_host_private_key" {
  type        = string
  description = "SSH private key for the remote_host_user."
  sensitive   = true
}

variable "kubeconfig_dependency" {
  type        = any
  description = "Dependency trigger to ensure kubeconfig is ready on the remote host."
}

variable "cluster_id" {
  type = string
  description = "OCID of the OKE cluster."
}

variable "cilium_version" {
  type = string
  default = "1.15.5" # Example
  description = "Cilium version to install."
}

variable "helm_chart_values_file_content" {
  type = string
  default = "" # Content of a values.yaml file, if any
  description = "Content of the Helm values file for Cilium."
}

resource "null_resource" "cilium" {
  count      = var.cilium_install ? 1 : 0

  triggers = {
    helm_version = var.cilium_helm_version
    crds_md5     = try(md5(join("\n", local.cilium_helm_crds)), null)
    manifest_md5 = try(md5(local.cilium_helm_values_override_yaml), null)
    reapply      = var.cilium_reapply ? uuid() : null
    cluster_id   = var.cluster_id
    kubeconfig_dep = sha1(jsonencode(var.kubeconfig_dependency))
    cilium_version = var.cilium_version
    values_content_sha = sha256(var.helm_chart_values_file_content)
  }

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.remote_host_ip
    user                = var.remote_host_user
    private_key         = var.remote_host_private_key
    timeout             = "40m"
    type                = "ssh"
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${local.yaml_manifest_path}"]
  }

  provisioner "file" {
    content     = join("\n", local.cilium_helm_crds)
    destination = local.cilium_helm_crds_file
  }

  provisioner "file" {
    content     = local.cilium_helm_values_override_yaml
    destination = local.cilium_helm_values_override_file
  }

  # provisioner "file" {
  #   content     = local.cilium_net_attach_def_yaml
  #   destination = local.cilium_net_attach_def_file
  # }

  # provisioner "file" {
  #   content     = local.cilium_veth_config_map_yaml
  #   destination = local.cilium_veth_config_map_file
  # }

  provisioner "remote-exec" {
    inline = [<<-EOT
      # Make sure $HOME/bin is on PATH if OCI-CLI or Helm were installed there
      export PATH="$HOME/bin:$PATH"
      set -euo pipefail
      echo "Deploying / upgrading Cilium via Helm…"
      helm repo add cilium https://helm.cilium.io || true
      helm repo update
      # Optionally create a temporary values file
      if [ -n "${var.helm_chart_values_file_content}" ]; then
        printf '%s\n' "${var.helm_chart_values_file_content}" > /tmp/cilium_values.yaml
      fi
      helm upgrade --install cilium cilium/cilium \
        --version ${var.cilium_version} \
        --namespace kube-system \
        --create-namespace \
        ${var.helm_chart_values_file_content != "" ? "-f /tmp/cilium_values.yaml" : ""} \
        --wait --timeout 10m0s
      # Clean up temp file
      [ -f /tmp/cilium_values.yaml ] && rm -f /tmp/cilium_values.yaml || true
    EOT
    ]
  }

  lifecycle {
    precondition {
      condition     = var.cni_type == "flannel"
      error_message = "Incompatible cni_type for installation - must be 'flannel'."
    }
  }
}