###############################################################################
# OKE layer – depends on network + bastion
###############################################################################

include "common" {
  path   = find_in_parent_folders("env-common.hcl")
  expose = true
}

# ─── dependencies ───────────────────────────────────────────────────────
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vcn_id             = "ocid1.vcn.oc1..mock"
    vcn_cidr_block     = "10.2.0.0/16"
    subnet_ids         = {
      workers   = "ocid1.subnet.oc1..mock"
      cp        = "ocid1.subnet.oc1..mock"
      pub_lb    = "ocid1.subnet.oc1..mock"
    }
    # OKE creates its own worker / kube-api NSGs, so we don't need any
    # of the pre-built ones here – leave the map empty or remove it.
  }
}

dependency "operator" {
  config_path = "../operator" // Adjust if your operator is in a different path

  mock_outputs = {
    private_ip                        = "10.0.0.100" // Placeholder
    user                              = "opc"        // Placeholder
    ssh_private_key_for_remote_exec   = "mock_ssh_private_key_content_for_operator" // Placeholder
    kubeconfig_setup_complete_trigger = "mock_kubeconfig_trigger_value_for_operator"
    id                                = "ocid1.instance.oc1..mockoperator"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

###############################################################################
# Terraform module
###############################################################################
terraform {
  source = "../../../../../terraform/modules/oci//oke"

  # When the cluster is ready, re-apply the Operator stack so it can
  # pull the kubeconfig.
  after_hook "generate_kubeconfig_on_operator" {
    commands = ["apply"]
    execute  = [
      "terragrunt",
      "apply",
      "--terragrunt-source-update",
      "--terragrunt-working-dir", "../operator",
      "--non-interactive",
      "-var", "generate_kubeconfig=true"
    ]
    run_on_error = false   # skip the hook if OKE apply failed
  }
}

###############################################################################
# Locals
###############################################################################
locals {
  env_name  = include.common.locals.env
  state_id  = "core-services"

  # ---------------------------------------------------------------------
  # SSH feature toggle – purely env-var based to avoid dependency look-ups
  # inside locals (not supported by Terragrunt's evaluation order).
  # If you export BASTION_SSH_KEY the remote-exec features will be enabled.
  ssh_available = length(get_env("BASTION_SSH_KEY", "")) > 0

  # worker_pools -----------------------------------------------------------
  worker_pools = {
    autoscaler_pool = {
      description     = "CA scheduling pool"
      shape           = "VM.Standard.E4.Flex"        # x86
      ocpus           = 1
      memory_in_gbs   = 16
      size            = 1
      labels          = { intent = "cluster-autoscaler" }
      allow_autoscaler = true
      autoscale        = false
    }

    services = {
      description     = "Application Services Pool"
      shape           = "VM.Standard.A1.Flex"         # ARM
      ocpus           = 2
      memory_in_gbs   = 32
      size            = 3
      min_size        = 2
      max_size        = 5
      labels          = { workload-type = "application" }
      node_labels     = { workload-type = "application" }
      allow_autoscaler = false
      autoscale        = true
      ignore_initial_pool_size = true
    }

    stateful_mq = {
      description     = "Stateful MQ Pool"
      shape           = "VM.Standard.A1.Flex"         # ARM
      ocpus           = 2
      memory_in_gbs   = 32
      size            = 2
      min_size        = 1
      max_size        = 3
      labels          = { workload-type = "stateful-mq" }
      node_labels     = { workload-type = "stateful-mq" }
      taints          = [{ key = "workload", value = "stateful-mq", effect = "NO_SCHEDULE" }]
      allow_autoscaler = false
      autoscale        = true
      ignore_initial_pool_size = true
    }

    stateful_db = {
      description     = "Stateful DB Pool"
      shape           = "VM.Standard.E4.Flex"         # x86
      ocpus           = 4
      memory_in_gbs   = 64
      size            = 3
      min_size        = 2
      max_size        = 4
      labels          = { workload-type = "stateful-db" }
      node_labels     = { workload-type = "stateful-db" }
      taints          = [{ key = "workload", value = "stateful-db", effect = "NO_SCHEDULE" }]
      allow_autoscaler = false
      autoscale        = true
      ignore_initial_pool_size = true
    }
  }

  # derived counters -------------------------------------------------------
  expected_node_count            = sum([for p in values(local.worker_pools) : p.size])
  expected_autoscale_worker_pools = length([for p in values(local.worker_pools) : p if p.autoscale == true])
}

###############################################################################
# Inputs for the OKE wrapper module
###############################################################################
inputs = merge(
  try(local.common_inputs, {}),
  {
    # ── mandatory ─────────────────────────────────────────────
    # list(string) as expected by the OKE wrapper module
    vcn_cidrs            = [dependency.network.outputs.vcn_cidr_block]

    # ---------------------------------------------------------
    # SSH private-key to reach the Operator VM: reuse the key
    # already passed to / output by the Operator stack.
    # ---------------------------------------------------------
    ssh_private_key = dependency.operator.outputs.ssh_private_key_for_remote_exec

    # ── IDs & naming ───────────────────────────────────────────────────────
    tenancy_ocid      = include.common.locals.tenancy_ocid
    compartment_id    = include.common.locals.compartment_ocid
    vcn_id            = dependency.network.outputs.vcn_id
    env_name          = local.env_name
    state_id          = local.state_id
    cluster_name      = "${local.env_name}-oke"
    cluster_type      = "ENHANCED_CLUSTER"
    kubernetes_version = "v1.33.0"
    region            = include.common.locals.region
    node_pool_name    = null

    # ── Networking ---------------------------------------------------------
    node_subnet_id          = dependency.network.outputs.subnet_ids["workers"]
    api_endpoint_subnet_id  = dependency.network.outputs.subnet_ids["cp"]
    service_lb_subnet_id    = [dependency.network.outputs.subnet_ids["pub_lb"]]
    # In OCI_VCN_IP_NATIVE mode (Calico) the pod CIDRs come from the VCN,
    # so this must be null (or simply omitted).
    pods_cidr               = null
    services_cidr           = "10.97.0.0/16"
    control_plane_is_public = false
    assign_public_ip_to_control_plane = false
    all_services_cidr       = dependency.network.outputs.all_services_cidr


    # ── NSG rules kept in vars-nsg-*.auto.tfvars files ─────────────────────
    nsg_app_rules     = []
    nsg_kubeapi_rules = []

    # --- SSH / remote-exec host details -------------------------------------
    bastion_host  = dependency.operator.outputs.private_ip
    bastion_user  = "opc"
    operator_host = dependency.operator.outputs.private_ip
    operator_user = "opc"

    # -------------------------------------------------------------------
    # SSH key & toggle
    # Prefer the key generated by the Bastion layer; fallback to env-var.
    # NOTE: For local runs with mocks where remote-exec is needed,
    #       you MUST export BASTION_SSH_KEY with the private key content.
    ssh_public_key = file(get_env("OKE_NODE_SSH_PUBLIC_KEY_PATH", "~/.ssh/oci_bastion_ed25519.pub"))

    # Always allow the extensions module to use the Operator VM
    operator_enabled = true

    # --- Extension toggles --------------------------------------------------
    # Force-install the common addons through the Operator VM
    cluster_autoscaler_install = true
    metrics_server_install     = true
    prometheus_install         = true

    # --- pass worker_pools & counters ---------------------------------------
    node_pool_config                = local.worker_pools
    expected_node_count             = local.expected_node_count
    expected_autoscale_worker_pools = local.expected_autoscale_worker_pools

    # ── Defaults: Calico + Cluster-autoscaler already ON ------------------
    cni_type = "oci_vcn_native"

    # minimal autoscaler settings
    cluster_autoscaler_namespace     = "kube-system"
    cluster_autoscaler_helm_version  = "9.29.0"
    cluster_autoscaler_helm_values   = {}
    cluster_autoscaler_helm_values_files = []

    # metrics-server – highly recommended with autoscaler
    metrics_server_namespace     = "kube-system"
    metrics_server_helm_version  = "3.11.0"
    metrics_server_helm_values   = {}
    metrics_server_helm_values_files = []
    prometheus_reapply          = false

    # Prometheus monitoring stack (optional but handy)
    prometheus_namespace        = "monitoring"
    prometheus_helm_version     = "55.5.0"
    prometheus_helm_values      = {}
    prometheus_helm_values_files = []

    # Security / OIDC (provide empty/false if not used)
    cluster_kms_key_id = ""
    image_signing_keys = []
    use_signed_images  = false
    oidc_discovery_enabled = false
    oidc_token_auth_enabled = false
    oidc_token_authentication_config = null

    # Tagging (provide empty/false if not used)
    tag_namespace                   = "oke"
    use_defined_tags                = false
    cluster_defined_tags            = {}
    cluster_freeform_tags           = {}
    persistent_volume_defined_tags  = {}
    persistent_volume_freeform_tags = {}
    service_lb_defined_tags         = {}
    service_lb_freeform_tags        = {}

    # Cluster Addons – enable the managed Calico add-on so that
    # Kubernetes NetworkPolicies work out-of-the-box.
    #
    # The add-on name must exactly match what the OCI API returns for
    # your Kubernetes version (run:
    #   oci ce addon list-options --kubernetes-version <ver>
    # ).  At the time of writing it is "OCI Calico".
    cluster_addons = {
      # Managed Calico is installed automatically for VCN Native clusters.

      "CertManager" = {
        enabled = true
      }

      "KubernetesMetricsServer" = {
        enabled = true
      }
    }
    cluster_addons_to_remove = []

    # Extensions (provide defaults, likely false/empty)
    cilium_install           = false
    cilium_reapply           = false
    cilium_namespace         = "kube-system"
    cilium_helm_version      = ""
    cilium_helm_values       = {}
    cilium_helm_values_files = []

    multus_install       = false
    multus_namespace     = "kube-system"
    multus_daemonset_url = ""
    multus_version       = ""

    sriov_device_plugin_install       = false
    sriov_device_plugin_namespace     = "kube-system"
    sriov_device_plugin_daemonset_url = ""
    sriov_device_plugin_version       = ""

    sriov_cni_plugin_install       = false
    sriov_cni_plugin_namespace     = "kube-system"
    sriov_cni_plugin_daemonset_url = ""
    sriov_cni_plugin_version       = ""

    rdma_cni_plugin_install       = false
    rdma_cni_plugin_namespace     = "kube-system"
    rdma_cni_plugin_daemonset_url = ""
    rdma_cni_plugin_version       = ""

    whereabouts_install       = false
    whereabouts_namespace     = "kube-system"
    whereabouts_daemonset_url = ""
    whereabouts_version       = ""


    mpi_operator_install        = false
    mpi_operator_namespace      = "default"
    mpi_operator_deployment_url = ""
    mpi_operator_version        = ""

    gatekeeper_install           = false
    gatekeeper_namespace         = "gatekeeper-system"
    gatekeeper_helm_version      = ""
    gatekeeper_helm_values       = {}
    gatekeeper_helm_values_files = []

    create_service_account = false
    service_accounts       = {}

    # leave the rest of the toggles at their defaults (false / empty) – can
    # be overridden in oke_vars/vars-extensions-*.auto.tfvars

    # Default node pool shape and image configurations required by the module
    default_node_pool_shape        = "VM.Standard.E4.Flex"
    
    
    # Explicit worker images (Toronto, Kubernetes v1.31) to avoid
    # shape/image compatibility errors.
    default_node_pool_image_id_amd = ""
    default_node_pool_image_id_arm = ""
    node_shape                     = "VM.Standard.E4.Flex" # Generic node_shape often used for module defaults

    # --- Inputs for OKE Extensions to use the Operator VM ---
    extensions_remote_host_ip              = dependency.operator.outputs.private_ip
    extensions_remote_host_user            = dependency.operator.outputs.user
    extensions_remote_host_private_key     = dependency.operator.outputs.ssh_private_key_for_remote_exec
  }
)

###############################################################################
# ─── IAM module for workers & autoscaler ─────────────────────────────────
###############################################################################
generate "oci_provider_alias" {
  path      = "provider_alias.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        oci = {
          source  = "oracle/oci"
          version = ">= 5.0.0"
          configuration_aliases = [oci.home]
        }
      }
    }

    provider "oci" {
      alias  = "home"
      region = var.region
    }

    # Inputs for the IAM module if it's directly part of this generated context
    # or ensure these are passed correctly if IAM is a submodule of OKE
    # This section might vary based on your exact IAM module integration
    # For now, focusing on the provider version.
    # Example:
    # variable "tenancy_id" { type = string }
    # variable "user_id" { type = string }
    # variable "fingerprint" { type = string }
    # variable "private_key_path" { type = string }

  EOF
}

generate "iam_module" {
  path      = "iam_module.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    module "iam" {
      source = "../iam"

      # hand the alias to the child module  ↓↓↓
      providers = {
        oci.home = oci.home    # oracle/oci provider alias
      }

      # ─── core identifiers ────────────────────────────────
      tenancy_id     = var.tenancy_ocid
      compartment_id = var.compartment_id
      cluster_id     = try(module.oke_cluster.id, "")
      state_id       = var.state_id

      # ─── compartments where IAM roles apply ──────────────
      worker_compartments     = [var.compartment_id]
      autoscaler_compartments = [var.compartment_id]

      # ─── which policies to create ────────────────────────
      create_iam_resources         = true  # master switch
      create_iam_worker_policy     = true  # nodes: join cluster, pull images
      create_iam_autoscaler_policy = true  # autoscaler: scale node-pools
      create_iam_operator_policy   = false
      create_iam_kms_policy        = false

      # ─── tagging / namespaces (disabled) ─────────────────
      tag_namespace              = "koci"
      use_defined_tags           = false
      create_iam_defined_tags    = false
      create_iam_tag_namespace   = false
      defined_tags               = {}
      freeform_tags              = {}

      policy_name                = "oke-${local.env_name}"

      # ─── optional KMS keys (empty if unused) ─────────────
      cluster_kms_key_id         = ""
      operator_volume_kms_key_id = ""
      worker_volume_kms_key_id   = ""
    }
  EOF
}

# --- single (authoritative) provider file -----------------------------------
generate "provider_alias_tf" {
  path      = "provider_alias.tf"     # same filename as the legacy one
  if_exists = "overwrite"             # ensure *our* content wins
  contents  = <<-EOF
    terraform {
      required_providers {
        oci = {
          source  = "oracle/oci"
          version = ">= 5.0.0"
          configuration_aliases = [oci.home]
        }
      }
    }

    # Default OCI provider – use the current region
    provider "oci" {
      region = var.region
    }

    # Alias for IAM operations in the tenancy's home region
    provider "oci" {
      alias  = "home"
      region = var.region   # adjust if your home region differs
    }
  EOF
} 