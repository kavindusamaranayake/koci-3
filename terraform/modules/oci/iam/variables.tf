# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Common
variable "cluster_id" { type = string }
variable "compartment_id" { type = string }
variable "state_id" { type = string }
variable "tenancy_id" { type = string }
variable "worker_compartments" { type = list(string) }

# Tags
variable "create_iam_defined_tags" { type = bool }
variable "create_iam_tag_namespace" { type = bool }
variable "defined_tags" { type = map(string) }
variable "freeform_tags" { type = map(string) }
variable "tag_namespace" { type = string }
variable "use_defined_tags" { type = bool }

# Policy
variable "autoscaler_compartments" { type = list(string) }
variable "create_iam_resources" { type = bool }
variable "create_iam_autoscaler_policy" { type = bool }
variable "create_iam_kms_policy" { type = bool }
variable "create_iam_operator_policy" { type = bool }
variable "create_iam_worker_policy" { type = bool }
variable "policy_name" { type = string }

# KMS
variable "cluster_kms_key_id" { type = string }
variable "operator_volume_kms_key_id" { type = string }
variable "worker_volume_kms_key_id" { type = string }

variable "create_policy_for_ocir_secret_read" {
  description = "Whether to create a policy that allows reading the OCIR secret"
  type        = bool
  default     = false
}

variable "ocir_secret_id" {
  description = "OCID of the secret in Vault that stores the OCIR auth token"
  type        = string
  default     = null
}

variable "worker_compartment_id" {
  description = "Compartment OCID where worker nodes live (for policy scoping)"
  type        = string
  default     = null
}

variable "worker_dynamic_group_id" {
  description = "Dynamic Group OCID that represents worker nodes"
  type        = string
  default     = null
}
