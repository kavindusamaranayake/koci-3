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

# Add any other variables used by prometheus.tf
variable "prometheus_install" {
  description = "Flag to install Prometheus."
  type        = bool
  default     = false
}

variable "prometheus_helm_version" {
  description = "Helm chart version for Prometheus."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
}

variable "prometheus_namespace" {
  description = "Namespace for Prometheus."
  type        = string
  default     = "monitoring"
}

variable "prometheus_helm_values" {
  description = "Helm values for Prometheus."
  type        = map(any)
  default     = {}
}

variable "prometheus_helm_values_files" {
  description = "List of Helm values files for Prometheus."
  type        = list(string)
  default     = []
}

variable "prometheus_reapply" {
  description = "Trigger reapply for prometheus."
  type        = bool
  default     = false
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

variable "output_log" {
  description = "Format string for output logging."
  type        = string
  default     = "echo '[%s] %s'"
} 