variable "compartment_id" {
  description = "Compartment OCID"
  type        = string      
}

variable "env_name" {
  description = "Environment name for tagging."
  type        = string
}

variable "vcn_id" {
  description = "The OCID of the VCN where the network security group will be created."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID of the root compartment (tenancy). Required only if `enabled` is true."
  type        = string
  default     = ""            # makes it optional when we disable the feature
  validation {
    condition     = var.enabled ? length(var.tenancy_ocid) > 0 : true
    error_message = "tenancy_ocid must be set when security-zone feature is enabled."
  }
}

variable "reporting_region" {
  description = "Preferred reporting region for Cloud Guard (leave null to use the home region)."
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether to create Cloud Guard configuration and a security zone."
  type        = bool
  default     = false
}

