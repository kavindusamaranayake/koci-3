###############################################################################
# Discover ADs *inside* the module and fail fast when the region is single-AD
###############################################################################
data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domains = [
    for ad in data.oci_identity_availability_domains.this.availability_domains : ad.name
  ]
}

output "availability_domains" {
  description = "Names of the availability domains detected in this region"
  value       = local.availability_domains
} 