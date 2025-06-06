variable "compartment_id" {
  description = "OCID of the compartment for OKE resources"
  type        = string
}

variable "vcn_id" {
  description = "OCID of the VCN"
  type        = string
}

variable "kubernetes_version" {
  description = "OKE Kubernetes version"
  type        = string
}


variable "node_subnet_id" {
  description = "OCID of the subnet for OKE nodes"
  type        = string
}

variable "api_endpoint_subnet_id" {
  description = "OCID of the subnet for Kubernetes API endpoint"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "env_name" {
  description = "Environment name for tagging"
  type        = string
}

variable "ssh_public_key" {
  description = "The public SSH key content to install on worker nodes."
  type        = string
  sensitive   = true # Contains potentially sensitive info
}

variable "all_services_cidr" {
  description = "CIDR block for all Oracle services"
  type        = string
}

variable "node_pool_config" {
  description = "Map of node-pool definitions"
  type = map(object({
    description   = string
    shape         = string
    ocpus         = number
    memory_in_gbs = number
    size          = number
    min_size      = optional(number)
    max_size      = optional(number)

    # Was required, now optional – OKE module works it out
    availability_domain = optional(string)

    labels       = map(string)
    node_labels  = optional(map(string))
    taints       = optional(list(object({
                     key    = string
                     value  = string
                     effect = string
                   })))

    autoscale                = bool
    ignore_initial_pool_size = optional(bool)

    image_id       = optional(string)
    node_metadata  = optional(map(string))
  }))
}

variable "nsg_app_rules" {
  description = "List of NSG rules for app nodes"
  type        = list(object({
    direction       = string
    protocol        = string
    cidr            = string
    cidr_type       = string
    port            = optional(number)
    port_max        = optional(number)
    source_port_min = optional(number)
    source_port_max = optional(number)
    icmp_type       = optional(number)
    icmp_code       = optional(number)
  }))
}

variable "nsg_kubeapi_rules" {
  description = "List of NSG rules for Kubernetes API"
  type        = list(object({
    direction       = string
    protocol        = string
    cidr            = string
    cidr_type       = string
    port            = optional(number)
    port_max        = optional(number)
    source_port_min = optional(number)
    source_port_max = optional(number)
    icmp_type       = optional(number)
    icmp_code       = optional(number)
  }))
}

variable "nsg_lb_rules" {
  description = "List of NSG rules for Load Balancer access to app nodes"
  type        = list(object({
    direction       = string
    protocol        = string
    cidr            = string
    cidr_type       = string
    port            = optional(number)
    port_max        = optional(number)
    source_port_min = optional(number)
    source_port_max = optional(number)
    icmp_type       = optional(number)
    icmp_code       = optional(number)
  }))
  default = []
}

variable "nsg_db_rules" {
  description = "List of NSG rules for App Nodes to reach DB subnet or DB NSG"
  type        = list(object({
    direction       = string
    protocol        = string
    cidr            = string
    cidr_type       = string
    port            = optional(number)
    port_max        = optional(number)
    source_port_min = optional(number)
    source_port_max = optional(number)
    icmp_type       = optional(number)
    icmp_code       = optional(number)
  }))
  default = []
}

# ------------------------------------------------------------------------------
#  New pass-through variables for sub-modules
# ------------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID – needed for AD lookup"
  type        = string
}

variable "state_id"               { type = string }
variable "cluster_name"           { type = string }
variable "cni_type"               { type = string }
variable "pods_cidr"              { type = string }
variable "services_cidr"          { type = string }
variable "service_lb_subnet_id"   { type = list(string) }
variable "assign_public_ip_to_control_plane" { type = bool }
variable "control_plane_is_public"            { type = bool }
variable "image_signing_keys"     { type = set(string) }
variable "use_signed_images"      { type = bool }

# Tagging
variable "tag_namespace"                  { type = string }
variable "use_defined_tags"               { type = bool }
variable "cluster_defined_tags"           { type = map(string) }
variable "cluster_freeform_tags"          { type = map(string) }
variable "persistent_volume_defined_tags" { type = map(string) }
variable "persistent_volume_freeform_tags"{ type = map(string) }
variable "service_lb_defined_tags"        { type = map(string) }
variable "service_lb_freeform_tags"       { type = map(string) }

# OIDC
variable "oidc_discovery_enabled"          { type = bool }
variable "oidc_token_auth_enabled"         { type = bool }
variable "oidc_token_authentication_config"{ type = any }

# Cluster-addons
variable "cluster_addons"            { type = any }
variable "cluster_addons_to_remove"  { type = any }

# Extensions – generic connection bits that many of them share
variable "region"            { type = string }
variable "expected_node_count" { type = number }
variable "vcn_cidrs"         { type = list(string) }
variable "bastion_host"      { type = string }
variable "bastion_user"      { type = string }
variable "operator_host"     { type = string }
variable "operator_user"     { type = string }
variable "ssh_private_key"   { type = string }
variable "operator_enabled"  { type = bool }

# Feature toggles (examples – extend as required)
variable "cilium_install"           { type = bool }
variable "cilium_reapply"           { type = bool }
variable "cilium_namespace"         { type = string }
variable "cilium_helm_version"      { type = string }
variable "cilium_helm_values"       { type = map(string) }
variable "cilium_helm_values_files" { type = list(string) }

variable "multus_install"       { type = bool }
variable "multus_namespace"     { type = string }
variable "multus_daemonset_url" { type = string }
variable "multus_version"       { type = string }

variable "metrics_server_install"            { type = bool }
variable "metrics_server_namespace"          { type = string }
variable "metrics_server_helm_version"       { type = string }
variable "metrics_server_helm_values"        { type = map(string) }
variable "metrics_server_helm_values_files"  { type = list(string) }

# ---------- Global defaults ----------

# Cluster-autoscaler is ON by default
variable "cluster_autoscaler_install" {
  type    = bool
  default = true
}

# ---------- Autoscaler (new variables but KEEP existing ones) ----------
variable "cluster_autoscaler_namespace"         { type = string }
variable "cluster_autoscaler_helm_version"      { type = string }
variable "cluster_autoscaler_helm_values"       { type = map(string) }
variable "cluster_autoscaler_helm_values_files" { type = list(string) }
variable "expected_autoscale_worker_pools"      { type = number }

# ---------- SR-IOV Device plugin ----------
variable "sriov_device_plugin_install"          { type = bool }
variable "sriov_device_plugin_namespace"        { type = string }
variable "sriov_device_plugin_daemonset_url"    { type = string }
variable "sriov_device_plugin_version"          { type = string }

# ---------- SR-IOV CNI plugin ----------
variable "sriov_cni_plugin_install"             { type = bool }
variable "sriov_cni_plugin_namespace"           { type = string }
variable "sriov_cni_plugin_daemonset_url"       { type = string }
variable "sriov_cni_plugin_version"             { type = string }

# ---------- RDMA CNI plugin ----------
variable "rdma_cni_plugin_install"              { type = bool }
variable "rdma_cni_plugin_namespace"            { type = string }
variable "rdma_cni_plugin_daemonset_url"        { type = string }
variable "rdma_cni_plugin_version"              { type = string }

# ---------- Whereabouts ----------
variable "whereabouts_install"                 { type = bool }
variable "whereabouts_namespace"               { type = string }
variable "whereabouts_daemonset_url"           { type = string }
variable "whereabouts_version"                 { type = string }

# ---------- Prometheus ----------
variable "prometheus_install"           { type = bool }
variable "prometheus_reapply"           { type = bool }
variable "prometheus_namespace"         { type = string }
variable "prometheus_helm_version"      { type = string }
variable "prometheus_helm_values"       { type = map(string) }
variable "prometheus_helm_values_files" { type = list(string) }

# ---------- MPI operator ----------
variable "mpi_operator_install"                { type = bool }
variable "mpi_operator_namespace"              { type = string }
variable "mpi_operator_deployment_url"         { type = string }
variable "mpi_operator_version"                { type = string }

# ---------- Gatekeeper ----------
variable "gatekeeper_install"                  { type = bool }
variable "gatekeeper_namespace"                { type = string }
variable "gatekeeper_helm_version"             { type = string }
variable "gatekeeper_helm_values"              { type = map(string) }
variable "gatekeeper_helm_values_files"        { type = list(string) }

# ---------- Service Account helper ----------
variable "create_service_account"              { type = bool }
variable "service_accounts"                    { type = map(any) }

variable "cluster_type" {
  description = "OKE cluster type. Valid values: ENHANCED_CLUSTER or BASIC_CLUSTER"
  type        = string
  default     = "ENHANCED_CLUSTER"
}

variable "default_node_pool_image_id" {
  description = <<EOT
If set, every node-pool that omits `image_id` will inherit this OCID.
If left empty, the module looks up the first supported OKE worker image for
the requested `kubernetes_version` in the current region.
EOT
  type    = string
  default = ""        # ← now optional
}

variable "yaml_manifest_path" {
  description = "Default path on the operator node for storing YAML manifests."
  type        = string
  default     = "/var/tmp/oke-yaml"
}

variable "kubectl_create_missing_ns" {
  description = "Command template to create a Kubernetes namespace if it's missing."
  type        = string
  default     = "kubectl create namespace %s || true"
}

variable "kubectl_apply_server_file" {
  description = "Command template to apply a Kubernetes manifest file."
  type        = string
  default     = "kubectl apply -f %s"
}

variable "output_log" {
  description = "Command template for logging output from remote-exec."
  type        = string
  default     = "echo '[%s] %s'"
}

############################################################################
# Optional encryption key for the cluster (referenced from main.tf)         #
############################################################################
variable "cluster_kms_key_id" {
  description = "OCID of the KMS key to be used as the master-encryption key for Kubernetes secrets."
  type        = string
  default     = null
}

variable "default_node_pool_shape" {
  type        = string
  description = "The default shape for nodes in the node pool. Used to determine the architecture for the bootstrap node pool image."
}

variable "default_node_pool_image_id_arm" {
  type        = string
  description = "The OCID of the ARM image to use for node pools."
}

variable "default_node_pool_image_id_amd" {
  type        = string
  description = "The OCID of the AMD/x86 image to use for node pools."
}

variable "node_shape" {
  type        = string
  description = "The shape of the nodes. Used to determine the architecture for node pool images."
  # This variable seems to be used in a context where it's iterated or accessed per node pool.
  # If it's meant to be a single value passed to the module for all node pools, this definition is fine.
  # If each node pool can have a different shape, you might need to adjust how this variable is structured and used.
}

variable "extensions_remote_host_ip" {
  type        = string
  description = "The IP address of the host from which to run OKE extensions (e.g., the operator VM)."
  nullable    = true
  default     = null
}

variable "extensions_remote_host_user" {
  type        = string
  description = "The SSH user for the extensions remote host."
  nullable    = true
  default     = null // Or a sensible default like "opc" if always the same
}

variable "extensions_remote_host_private_key" {
  type        = string
  description = "The SSH private key content for connecting to the extensions remote host."
  sensitive   = true
  nullable    = true
  default     = null
}

variable "extensions_kubeconfig_dependency_trigger" {
  type        = any # Can be a string, number, or any value that changes
  description = "A trigger value that extensions can depend on to ensure kubeconfig is ready on the remote host. Typically an ID of a null_resource from the operator module."
  nullable    = true
  default     = null
}