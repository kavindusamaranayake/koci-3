# Block Volume for MongoDB Data
# This assumes static provisioning. If using dynamic provisioning with a StorageClass,
# this resource might not be needed, or you might define the StorageClass here instead.
resource "oci_core_volume" "mongodb_data" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = var.mongodb_volume_name
  size_in_gbs         = var.mongodb_volume_size_gb
  freeform_tags       = var.tags
  kms_key_id          = var.kms_key_id # Use Vault key for encryption if provided

  # Optional: Configure backup policy
  # is_auto_tune_enabled = true # For performance auto-tuning
  # vpus_per_gb = 10 # Performance level (10, 20, etc.)

  # Optional: Define block volume replication (cross-AD)
  # block_volume_replicas {
  #   availability_domain = "other-ad-identifier"
  #   display_name        = "${var.mongodb_volume_name}-replica"
  # }

  lifecycle {
    # If key rotation happens, the key version might change.
    # Depending on policy, you might want Terraform to update this or ignore it.
    ignore_changes = [kms_key_id]
  }
}

# Block Volume Backup Policy (Example - configure as needed)
# resource "oci_core_volume_backup_policy" "mongodb_backup_policy" {
#   compartment_id = var.compartment_id
#   display_name   = "mongodb-backup-policy"
#   schedules {
#     backup_type      = "INCREMENTAL"
#     period           = "ONE_DAY"
#     hour_of_day      = 2 # Example: 2 AM UTC
#     retention_seconds = 604800 # 7 days
#   }
#   schedules {
#     backup_type      = "FULL"
#     period           = "ONE_WEEK"
#     day_of_week      = "SATURDAY"
#     hour_of_day      = 4 # Example: 4 AM UTC on Saturday
#     retention_seconds = 2592000 # 30 days
#   }
# }

# Assign the backup policy to the volume
# resource "oci_core_volume_backup_policy_assignment" "mongodb_policy_assignment" {
#   asset_id = oci_core_volume.mongodb_data.id
#   policy_id = oci_core_volume_backup_policy.mongodb_backup_policy.id
# } 