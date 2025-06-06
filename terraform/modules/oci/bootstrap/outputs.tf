output "compartment_ocids" {
  description = "Map of environment name to compartment OCID"
  value       = local.env_compartment_ids
}

output "tf_user_ocids" {
  description = "Map of environment name to Terraform user OCID"
  value       = local.tf_user_ids
}

output "tf_group_ids" {
  description = "Map of environment name to Terraform group OCID"
  value       = local.tf_group_ids
}

output "tfstate_bucket_names" {
  description = "Map of environment name to TFState bucket name"
  value       = local.tfstate_bucket_names
}

output "tfstate_bucket_namespace" {
  description = "Object Storage namespace used for TFState buckets"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "tag_namespace_id" {
  description = "OCID of the tag namespace"
  value       = local.tag_namespace_id
}

output "kms_key_id" {
  description = "OCID of the KMS key used for TFState buckets (null if not created/provided)"
  value       = local.effective_kms_key_id
}

output "tf_user_api_key_fingerprints" {
  description = "Map of environment name to Terraform user API key fingerprint"
  value       = local.tf_api_key_fps
}

output "tf_user_api_key_ids" {
  description = "Map of environment name to Terraform user API key ID"
  value       = local.tf_api_key_ids
}

# Note: Do NOT output tf_private_keys as it's sensitive.
# It's used internally to populate Doppler secrets. 