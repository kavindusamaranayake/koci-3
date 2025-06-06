variable "tenancy_ocid"  { type = string }
variable "region"        { type = string }

variable "environments" {
  description = "Map of environment name → OCI region"
  type        = map(string)           # e.g. { Dev = "ca-montreal-1" }
  default     = { dev = "ca-montreal-1" }
}

variable "doppler_project" { type = string }

variable "parent_compartment_ocid" {
  type    = string
  default = ""                       
}

variable "kms_key_id" {
  type    = string
  default = ""                       
}

variable "create_kms_resources" {
  type        = bool
  description = "If true and kms_key_id is not provided, create a new KMS Vault and Key. If false, KMS resources will not be created by this module (buckets will use Oracle-managed keys unless kms_key_id is provided)."
  default     = true
}

variable "kms_rotation_period_days" {
  type        = number
  description = "How often the generated KMS key should rotate (days)"
  default     = 90
}

variable "tag_namespace_name" {
  type    = string
  default = "koci"
}

variable "common_tags" {
  type    = map(string)
  default = { ManagedBy = "koci-Terraform" }
}

# ---------------------------------------------------------------------------
# If false (default) → compartments and tag-namespace are protected from
# ---------------------------------------------------------------------------
variable "allow_compartment_destroy" {
  type        = bool
  description = "Permit Terraform to destroy the env compartment & tag namespace"
  default     = false
}

# ------------------------------------------------------------------
#  Generic prefix used in ALL generated resource names
# ------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix prepended to every env-specific slug (e.g. koci)"
  type        = string
  default     = "koci"
} 