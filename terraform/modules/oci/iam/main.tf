resource "oci_identity_policy" "ocir_secret_read" {
  count          = var.create_policy_for_ocir_secret_read ? 1 : 0
  compartment_id = var.worker_compartment_id
  name           = "allow-ocir-secret-read"
  description    = "Allow worker nodes to read OCIR secret"
  statements = [
    "Allow dynamic-group ${var.worker_dynamic_group_id} to read secrets in compartment id ${var.worker_compartment_id} where target.secret.id = '${var.ocir_secret_id}'"
  ]
} 