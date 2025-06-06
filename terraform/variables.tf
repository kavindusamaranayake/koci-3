variable "create_state_bucket" {
  description = "Whether to create the OCI bucket used for Terraform state. Set to false when the bucket already exists or is managed elsewhere."
  type    = bool
  default = false
} 