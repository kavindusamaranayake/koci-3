# Create the OCI Vault
resource "oci_kms_vault" "shared_vault" {
  compartment_id = var.compartment_id
  display_name   = var.vault_display_name
  vault_type     = var.vault_type
  freeform_tags  = var.tags
}

# Create a Master Encryption Key for Terraform State Encryption
resource "oci_kms_key" "tfstate_key" {
  compartment_id = var.compartment_id
  display_name   = var.tfstate_key_display_name
  key_shape {
    algorithm = "AES"
    length    = 32 # AES-256
  }
  management_endpoint = oci_kms_vault.shared_vault.management_endpoint
  freeform_tags       = var.tags
  # protection_mode = "HSM" # Consider HSM for production
}

# Create a Master Encryption Key for Data Encryption (Volumes, DBs)
resource "oci_kms_key" "data_key" {
  compartment_id = var.compartment_id
  display_name   = var.data_key_display_name
  key_shape {
    algorithm = "AES"
    length    = 32 # AES-256
  }
  management_endpoint = oci_kms_vault.shared_vault.management_endpoint
  freeform_tags       = var.tags
  # protection_mode = "HSM" # Consider HSM for production
}

# Generate a random password ONLY for the initial creation of the secret
resource "random_password" "db_admin_password_initial" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create the Database Admin Password Secret in the Vault
resource "oci_vault_secret" "db_admin_password" {
  compartment_id = var.compartment_id
  secret_name    = var.db_admin_secret_name
  key_id = oci_kms_key.data_key.id
  vault_id       = oci_kms_vault.shared_vault.id
  description    = "Admin password for the koci MySQL HeatWave database"
  freeform_tags  = var.tags
  # key_id         = oci_kms_key.data_key.id # Optional: Encrypt the secret itself with a key

  secret_content {
    content_type = "BASE64"
    # Use the randomly generated password for the *first* version.
    # Subsequent updates should happen via OCI console/CLI for rotation.
    content = base64encode(random_password.db_admin_password_initial.result)
  }

  # IMPORTANT: Prevent Terraform from trying to overwrite the secret content
  # if it's rotated or changed outside of this initial Terraform apply.
  lifecycle {
    ignore_changes = [secret_content]
  }


} 


