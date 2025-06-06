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

# Add any other variables used by metricserver.tf
variable "metrics_server_install" {
  description = "Flag to install metrics server."
  type        = bool
  default     = false
}

variable "expected_node_count" {
  description = "Expected number of nodes in the cluster."
  type        = number
  default     = 0
}

variable "metrics_server_helm_version" {
  description = "Helm chart version for metrics server."
  type        = string
  default     = "3.8.2" # Example default
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
}

variable "metrics_server_namespace" {
  description = "Namespace for metrics server."
  type        = string
  default     = "kube-system"
}

variable "metrics_server_helm_values_files" {
  description = "List of Helm values files for metrics server."
  type        = list(string)
  default     = []
}

variable "metrics_server_helm_values" {
  description = "Helm values for metrics server."
  type        = map(any)
  default     = {}
}

variable "yaml_manifest_path" {
  description = "Path for YAML manifests."
  type        = string
  default     = "/var/tmp/oke-yaml" # Or a suitable default
}

variable "kubectl_create_missing_ns" {
  description = "Kubectl command to create namespace."
  type        = string
  default     = "kubectl create namespace %s || true"
}

variable "kubectl_apply_server_file" {
  description = "Kubectl command to apply a file."
  type        = string
  default     = "kubectl apply -f %s"
} 