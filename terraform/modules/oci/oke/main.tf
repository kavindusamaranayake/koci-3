# Data source to get Availability Domains for the compartment's region
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid # Use tenancy OCID to list ADs for the region
}

module "oke_cluster" {
  source = "../cluster"

  # ---------- Core ----------
  compartment_id                     = var.compartment_id
  state_id                           = var.state_id
  vcn_id                             = var.vcn_id
  kubernetes_version                 = var.kubernetes_version
  cluster_name                       = var.cluster_name
  cluster_type                       = var.cluster_type

  # ---------- Networking ----------
  cni_type                           = var.cni_type
  pods_cidr                          = var.pods_cidr
  services_cidr                      = var.services_cidr
  control_plane_subnet_id            = var.api_endpoint_subnet_id
  control_plane_is_public            = var.control_plane_is_public
  control_plane_nsg_ids              = [module.kube_api_nsg.nsg_id]
  assign_public_ip_to_control_plane  = var.assign_public_ip_to_control_plane
  service_lb_subnet_id               = var.service_lb_subnet_id

  # ---------- Security / OIDC ----------
  cluster_kms_key_id                 = var.cluster_kms_key_id
  image_signing_keys                 = var.image_signing_keys
  use_signed_images                  = var.use_signed_images
  oidc_discovery_enabled             = var.oidc_discovery_enabled
  oidc_token_auth_enabled            = var.oidc_token_auth_enabled
  oidc_token_authentication_config   = var.oidc_token_authentication_config

  # ---------- Tagging ----------
  tag_namespace                      = var.tag_namespace
  use_defined_tags                   = var.use_defined_tags
  cluster_defined_tags               = var.cluster_defined_tags
  cluster_freeform_tags              = var.cluster_freeform_tags
  persistent_volume_defined_tags     = var.persistent_volume_defined_tags
  persistent_volume_freeform_tags    = var.persistent_volume_freeform_tags
  service_lb_defined_tags            = var.service_lb_defined_tags
  service_lb_freeform_tags           = var.service_lb_freeform_tags
}

resource "oci_containerengine_node_pool" "node_pool" {
  for_each       = var.node_pool_config
  compartment_id = var.compartment_id
  cluster_id     = module.oke_cluster.id
  name           = try(each.value.name, "${var.env_name}-${each.key}-nodepool")
  kubernetes_version = var.kubernetes_version

  node_shape = each.value.shape
  node_shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  ssh_public_key = var.ssh_public_key

  # ─────────── Node Source (Image) ───────────
  node_source_details {
    image_id = coalesce(
      try(each.value.image_id, null),
      try(var.default_node_pool_image_id, null),
      (
        strcontains(lower(each.value.shape), ".a1.")
        ? (
            length(trimspace(var.default_node_pool_image_id_arm)) > 0 ? var.default_node_pool_image_id_arm : local.resolved_default_image_id_arm
          )
        : (
            length(trimspace(var.default_node_pool_image_id_amd)) > 0 ? var.default_node_pool_image_id_amd : local.resolved_default_image_id_amd
          )
      ),
      local.resolved_default_image_id
    )
    source_type = "IMAGE"
  }

  # ─────────── required placement & size ───────
  node_config_details {
    size = try(each.value.size, 1)

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.node_subnet_id
    }

    # ────────── Pod networking option (VCN Native) ──────────
    dynamic "node_pool_pod_network_option_details" {
      for_each = var.cni_type == "oci_vcn_native" ? [1] : []
      content {
        cni_type       = "OCI_VCN_IP_NATIVE"
        # As of OCI provider v7.x, pod_subnet_ids is required for OCI_VCN_IP_NATIVE.
        # Re-use the worker subnet when a dedicated pod subnet is not provided.
        pod_subnet_ids = [var.node_subnet_id]
      }
    }

    # Optional extra NSGs coming from the pool map
    nsg_ids = try(each.value.nsg_ids, null)
  }

  # ─────────── initial node-labels ─────────────
  dynamic "initial_node_labels" {
    for_each = merge(
      try(each.value.node_labels, {}),
      try(each.value.labels,       {})
    )
    iterator = lbl
    content {
      key   = lbl.key
      value = lbl.value
    }
  }

  # ─────────── lifecycle ───────────
  lifecycle {
    ignore_changes = [
      node_config_details[0].size,
    ]
  }

  timeouts {
     create = "60m"
     update = "90m"
     delete = "60m"
  }

  defined_tags  = var.use_defined_tags ? merge(var.cluster_defined_tags, try(each.value.defined_tags, {})) : {}
  freeform_tags = merge(var.cluster_freeform_tags, try(each.value.freeform_tags, {}))
}

module "cluster_addons" {
  source = "../cluster-addons"

  cluster_id               = module.oke_cluster.id
  kubernetes_version       = var.kubernetes_version
  cluster_addons           = var.cluster_addons
  cluster_addons_to_remove = var.cluster_addons_to_remove

  # SSH / bastion for any remote execs inside that module
  bastion_host    = var.bastion_host
  bastion_user    = var.bastion_user
  operator_host   = var.operator_host
  operator_user   = var.operator_user
  ssh_private_key = var.ssh_private_key
  operator_enabled = var.operator_enabled
}

module "extensions" {
  source = "../extensions"

  # Pass through the new variables for remote execution
  remote_host_ip          = var.extensions_remote_host_ip
  remote_host_user        = var.extensions_remote_host_user
  remote_host_private_key = var.extensions_remote_host_private_key
  kubeconfig_dependency   = local.extensions_kubeconfig_hash

  # Pass other necessary inputs to extensions
  cluster_id              = module.oke_cluster.id
  bastion_public_ip       = var.extensions_remote_host_ip
  bastion_ssh_user        = var.extensions_remote_host_user
  bastion_ssh_private_key = var.extensions_remote_host_private_key

  # ---------- Core ----------
  region                 = var.region
  state_id               = var.state_id
  worker_pools           = var.node_pool_config          # re-use pool map
  kubernetes_version     = var.kubernetes_version
  expected_node_count    = var.expected_node_count
  cluster_private_endpoint = module.oke_cluster.private_endpoint

  # ---------- Connection ----------
  bastion_host    = var.bastion_host
  bastion_user    = var.bastion_user
  operator_host   = var.operator_host
  operator_user   = var.operator_user
  ssh_private_key = var.ssh_private_key

  # ---------- Networking / CNI ----------
  vcn_cidrs  = var.vcn_cidrs
  cni_type   = var.cni_type
  pods_cidr  = var.pods_cidr

  # ---------- Feature toggles & helm values ----------
  # Simply forward everything that the extensions module needs.
  # (Add any additional variables you enable later.)
  cilium_install           = var.cilium_install
  cilium_reapply           = var.cilium_reapply
  cilium_namespace         = var.cilium_namespace
  cilium_helm_version      = var.cilium_helm_version
  cilium_helm_values       = var.cilium_helm_values
  cilium_helm_values_files = var.cilium_helm_values_files

  multus_install           = var.multus_install
  multus_namespace         = var.multus_namespace
  multus_daemonset_url     = var.multus_daemonset_url
  multus_version           = var.multus_version

  metrics_server_install        = var.metrics_server_install
  metrics_server_namespace      = var.metrics_server_namespace
  metrics_server_helm_version   = var.metrics_server_helm_version
  metrics_server_helm_values    = var.metrics_server_helm_values
  metrics_server_helm_values_files = var.metrics_server_helm_values_files

  cluster_autoscaler_install        = var.cluster_autoscaler_install
  cluster_autoscaler_namespace      = var.cluster_autoscaler_namespace
  cluster_autoscaler_helm_version   = var.cluster_autoscaler_helm_version
  cluster_autoscaler_helm_values    = var.cluster_autoscaler_helm_values
  cluster_autoscaler_helm_values_files = var.cluster_autoscaler_helm_values_files
  expected_autoscale_worker_pools   = var.expected_autoscale_worker_pools

  prometheus_install           = var.prometheus_install
  prometheus_reapply           = var.prometheus_reapply
  prometheus_namespace         = var.prometheus_namespace
  prometheus_helm_version      = var.prometheus_helm_version
  prometheus_helm_values       = var.prometheus_helm_values
  prometheus_helm_values_files = var.prometheus_helm_values_files

  # ---------- Device / CNI plugins ----------
  sriov_device_plugin_install         = var.sriov_device_plugin_install
  sriov_device_plugin_namespace       = var.sriov_device_plugin_namespace
  sriov_device_plugin_daemonset_url   = var.sriov_device_plugin_daemonset_url
  sriov_device_plugin_version         = var.sriov_device_plugin_version

  sriov_cni_plugin_install            = var.sriov_cni_plugin_install
  sriov_cni_plugin_namespace          = var.sriov_cni_plugin_namespace
  sriov_cni_plugin_daemonset_url      = var.sriov_cni_plugin_daemonset_url
  sriov_cni_plugin_version            = var.sriov_cni_plugin_version

  rdma_cni_plugin_install             = var.rdma_cni_plugin_install
  rdma_cni_plugin_namespace           = var.rdma_cni_plugin_namespace
  rdma_cni_plugin_daemonset_url       = var.rdma_cni_plugin_daemonset_url
  rdma_cni_plugin_version             = var.rdma_cni_plugin_version

  whereabouts_install                 = var.whereabouts_install
  whereabouts_namespace               = var.whereabouts_namespace
  whereabouts_daemonset_url           = var.whereabouts_daemonset_url
  whereabouts_version                 = var.whereabouts_version

  # ---------- Operators / policy ----------
  mpi_operator_install                = var.mpi_operator_install
  mpi_operator_namespace              = var.mpi_operator_namespace
  mpi_operator_deployment_url         = var.mpi_operator_deployment_url
  mpi_operator_version                = var.mpi_operator_version

  gatekeeper_install                  = var.gatekeeper_install
  gatekeeper_namespace                = var.gatekeeper_namespace
  gatekeeper_helm_version             = var.gatekeeper_helm_version
  gatekeeper_helm_values              = var.gatekeeper_helm_values
  gatekeeper_helm_values_files        = var.gatekeeper_helm_values_files

  # ---------- Service-accounts helper ----------
  create_service_account              = var.create_service_account
  service_accounts                    = var.service_accounts
}

# ─────────── Discover available worker images (once per module) ──────────
data "oci_containerengine_node_pool_option" "node_pool_opts" {
  node_pool_option_id = "all"
}

locals {
  # Extract the bare Kubernetes version number (e.g. 1.33.0) from the
  # value that the caller passes (they usually include the leading "v").
  requested_k8s_version = replace(var.kubernetes_version, "v", "")

  # Candidate list (AMD/x86) that matches the requested version
  candidate_images_amd_for_version = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && !strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && strcontains(upper(s.source_name), "-OKE-${local.requested_k8s_version}-")
  ]

  # Candidate list (ARM/AArch64) that matches the requested version
  candidate_images_arm_for_version = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && strcontains(upper(s.source_name), "-OKE-${local.requested_k8s_version}-")
  ]

  # Fallback ARM list (any version, prefer matching Gen2 where present)
  candidate_images_arm = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && (
      strcontains(lower(s.source_name), "gen2")
      || !anytrue([
           for t in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
           strcontains(lower(t.source_name), "gen2") && strcontains(lower(t.source_name), "aarch64")
         ])
    )
  ]

  # Fallback AMD/x86 list (any version, prefer matching Gen2 where present)
  candidate_images_amd = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && !strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && (
      strcontains(lower(s.source_name), "gen2")
      || !anytrue([
           for t in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
           strcontains(lower(t.source_name), "gen2") && !strcontains(lower(t.source_name), "aarch64")
         ])
    )
  ]

  # ---------------- Platform (non-OKE) image lists --------------------------
  platform_images_amd = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && !strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && !strcontains(upper(s.source_name), "-OKE-")
  ]

  platform_images_arm = [
    for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
    s.image_id
    if  s.source_type == "IMAGE"
    && strcontains(lower(s.source_name), "aarch64")
    && !strcontains(lower(s.source_name), "gpu")
    && !strcontains(upper(s.source_name), "-OKE-")
  ]

  # -------------------------------------------------------------------------
  # Architecture-specific resolved defaults (priority order):
  #   1. OKE image matching requested version
  #   2. Platform image (version agnostic)
  #   3. Generic fallback list (Gen2 preference)
  # -------------------------------------------------------------------------
  resolved_default_image_id_amd = coalesce(
    length(local.candidate_images_amd_for_version) > 0 ? local.candidate_images_amd_for_version[0] : null,
    length(local.platform_images_amd)             > 0 ? local.platform_images_amd[0]             : null,
    length(local.candidate_images_amd)            > 0 ? local.candidate_images_amd[0]            : null
  )

  resolved_default_image_id_arm = coalesce(
    length(local.candidate_images_arm_for_version) > 0 ? local.candidate_images_arm_for_version[0] : null,
    length(local.platform_images_arm)             > 0 ? local.platform_images_arm[0]             : null,
    length(local.candidate_images_arm)            > 0 ? local.candidate_images_arm[0]            : null
  )

  # Generic resolved image (fallback for any arch)
  resolved_default_image_id = coalesce(
    local.resolved_default_image_id_amd,
    local.resolved_default_image_id_arm,
    # ultimate fallback: first IMAGE, any arch
    element([
      for s in data.oci_containerengine_node_pool_option.node_pool_opts.sources :
      s.image_id if s.source_type == "IMAGE"
    ], 0)
  )

  extensions_kubeconfig_hash = sha1(jsonencode(var.extensions_kubeconfig_dependency_trigger))
}