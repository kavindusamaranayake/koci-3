variable "compartment_id" {
  description = "The OCID of the compartment where the cluster resides."
  type        = string
}

variable "cluster_name" {
  description = "The name of the OKE cluster."
  type        = string
}

variable "operator_user" {
  description = "The SSH user for the operator node."
  type        = string
}

variable "region" {
  description = "The OCI region for the cluster."
  type        = string
}

# Variables for the connection block, ensure these are also passed if not defaulted
variable "bastion_host" {
  description = "Bastion host IP or hostname for SSH connection."
  type        = string
  default     = null
}

variable "bastion_user" {
  description = "Bastion host user for SSH connection."
  type        = string
  default     = null
}

variable "ssh_private_key" {
  description = "Path to the SSH private key for connection."
  type        = string
  sensitive   = true
}

variable "operator_host" {
  description = "Operator host IP or hostname for SSH connection."
  type        = string
}

# Add any other variables used by autoscaler.tf, like those for Helm values
variable "cluster_autoscaler_helm_values" {
  description = "Helm values for the cluster autoscaler."
  type        = map(any)
  default     = {}
}

variable "cluster_autoscaler_helm_values_files" {
  description = "List of Helm values files for the cluster autoscaler."
  type        = list(string)
  default     = []
}

variable "worker_pools_autoscaling" {
  description = "Configuration for worker pools autoscaling."
  type        = any # Adjust type as per actual structure
  default     = {}
}

variable "yaml_manifest_path" {
  description = "Path for YAML manifests."
  type        = string
  default     = "/var/tmp/oke-yaml" # Or a suitable default
} 