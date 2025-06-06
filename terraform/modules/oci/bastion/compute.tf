locals {
  boot_volume_size = tonumber(lookup(var.shape, "boot_volume_size", 50))
  memory           = tonumber(lookup(var.shape, "memory", 4))
  ocpus            = max(1, tonumber(lookup(var.shape, "ocpus", 1)))
  shape            = lookup(var.shape, "shape", "VM.Standard.E4.Flex")

  # ── choose availability domain ──────────────────────────────────
  resolved_ad = (
    var.availability_domain != ""
      ? var.availability_domain
      : data.oci_identity_availability_domains.ads.availability_domains[0].name
  )

  # The key we will place in opc's authorized_keys
  authorized_key = (
    var.ssh_public_key != ""
      ? var.ssh_public_key
      : tls_private_key.ssh[0].public_key_openssh
  )
}

# Look up ADs in the tenancy
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_id          # tenancy OCID
}

output "id" {
  value = oci_core_instance.bastion.id
}

output "public_ip" {
  value = oci_core_instance.bastion.public_ip
}

resource "oci_core_instance" "bastion" {
  availability_domain = local.resolved_ad
  compartment_id      = var.compartment_id
  display_name        = var.instance_display_name != "" ? var.instance_display_name : "bastion-${var.state_id}"
  defined_tags        = var.defined_tags
  freeform_tags       = var.freeform_tags
  shape               = lookup(var.shape, "shape")

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  create_vnic_details {
    assign_public_ip = var.is_public
    display_name     = var.instance_display_name != "" ? var.instance_display_name : "bastion-${var.state_id}"
    hostname_label   = var.assign_dns ? (
                        var.hostname_label != "" ?
                        var.hostname_label :
                        "${var.state_id}-bastion"
                      ) : null
    nsg_ids          = length(var.nsg_ids) > 0 ? var.nsg_ids : null
    subnet_id        = var.subnet_id
  }

  metadata = merge(
    { user_data = data.cloudinit_config.bastion.rendered },
    local.authorized_key != "" ? { ssh_authorized_keys = local.authorized_key } : {}
  )

  dynamic "shape_config" {
    for_each = length(regexall("Flex", local.shape)) > 0 ? [1] : []
    content {
      ocpus         = local.ocpus
      memory_in_gbs = (local.memory / local.ocpus) > 64 ? (local.ocpus * 4) : local.memory
    }
  }

  source_details {
    boot_volume_size_in_gbs = local.boot_volume_size
    source_id               = local.effective_image_id
    source_type             = "image"
  }

  lifecycle {
    ignore_changes = [
      availability_domain,
      defined_tags, freeform_tags, display_name,
      create_vnic_details, metadata, source_details,
    ]

    precondition {
      condition     = length(local.effective_image_id) > 0
      error_message = "Auto-lookup of Oracle Linux ${var.bastion_image_os_version} image failed. Supply image_id manually."
    }
  }

  timeouts {
    create = "60m"
  }
}
