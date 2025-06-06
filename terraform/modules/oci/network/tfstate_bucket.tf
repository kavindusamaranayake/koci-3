resource "oci_objectstorage_bucket" "tfstate" {
  # Hard-disable creation
  count = 0     # ← NEVER create in any workspace / env

  # TODO(koci): enable once bucket ownership is finalised
  # count = var.create_state_bucket ? 1 : 0

  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.bucket_name
  storage_tier   = "Standard"

  freeform_tags = merge(var.common_tags, {
    ManagedBy = "Terraform"
  })
} 