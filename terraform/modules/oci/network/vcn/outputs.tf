output "vcn_id" {
  description = "The OCID of the VCN created by this module."
  value       = oci_core_vcn.main.id
}

output "vcn_cidr_block" {
  description = "The CIDR block of the VCN."
  value       = oci_core_vcn.main.cidr_blocks[0]
}

output "igw_id" {
  description = "OCID of the Internet-Gateway (null if not created)"
  value = (
    length(oci_core_internet_gateway.igw) > 0
    ? oci_core_internet_gateway.igw[0].id
    : null
  )
}

output "ngw_id" {
  description = "OCID of the NAT-Gateway (null if not created)"
  value = (
    length(oci_core_nat_gateway.ngw) > 0
    ? oci_core_nat_gateway.ngw[0].id
    : null
  )
}

output "sgw_id" {
  description = "OCID of the Service-Gateway (null if not created)"
  value = (
    length(oci_core_service_gateway.sgw) > 0
    ? oci_core_service_gateway.sgw[0].id
    : null
  )
}

output "service_gateway_service_cidr" {
  description = "The CIDR block for the 'All Services in Oracle Services Network' target used by the Service Gateway."
  value       = local.service_gateway_service_cidr
}

output "drg_attachment_id" {
  description = "OCID of the VCN ↔ DRG attachment (null if DRG not created)."
  value       = try(oci_core_drg_attachment.vcn[0].id, null)
} 