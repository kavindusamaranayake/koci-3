data "oci_core_images" "ol_latest" {
  count = var.image_id == "" ? 1 : 0

  compartment_id            = var.compartment_id
  operating_system          = "Oracle Linux"
  operating_system_version  = var.bastion_image_os_version

  # NEW / RESTORED ─────────────────────────────────────────────────
  # ensure OCI only returns images that can run on the requested shape
  shape = local.shape                       # e.g. "VM.Standard.E4.Flex"

  # newest first
  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

locals {
  # Resolved image to use (may still be empty → checked later)
  effective_image_id = (
    var.image_id != "" ?
      var.image_id :
      try(data.oci_core_images.ol_latest[0].images[0].id, "")
  )
} 