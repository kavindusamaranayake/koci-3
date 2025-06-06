###############################################################################
# Discover ADs *inside* the module and fail fast when the region is single-AD
###############################################################################
data "oci_identity_availability_domains" "this" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaclenjvfd4xb37sr5mcduaygjpiklltchacalt2a3en2ay7m6wkiq"
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