output "vault_id" {
  description = "The OCID of the shared OCI Vault."
  value       = oci_kms_vault.shared_vault.id
}

output "tfstate_key_ocid" {
  description = "The OCID of the Master Key for Terraform state encryption."
  value       = oci_kms_key.tfstate_key.id
}

output "data_key_ocid" {
  description = "The OCID of the Master Key for data encryption."
  value       = oci_kms_key.data_key.id
}

output "db_admin_secret_ocid" {
  description = "The OCID of the secret containing the DB admin password."
  value       = oci_vault_secret.db_admin_password.id
} 