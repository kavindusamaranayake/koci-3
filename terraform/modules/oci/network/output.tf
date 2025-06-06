output "subnet_availability_domains" {
  value = { for k, s in module.subnet : k => s.availability_domain }
} 

output "vcn_id" {
  description = "The OCID of the VCN created by this module."
  value       = module.vcn.vcn_id
}

output "vcn_cidr_block" {
  description = "The CIDR block of the VCN."
  value       = module.vcn.vcn_cidr_block
}

output "igw_id" {
  description = "The OCID of the Internet Gateway created by this module."
  value       = module.vcn.igw_id
}

output "ngw_id" {
  description = "The OCID of the NAT Gateway created by this module."
  value       = module.vcn.ngw_id
}

output "sgw_id" {
  description = "The OCID of the Service Gateway created by this module."
  value       = module.vcn.sgw_id
}

# ---------------------------------------------------------------------------
# Map <subnet-name> → OCID so that other stacks (OKE, DB, LB…) can depend on
# the network layer without hard-coding subnet names.
# ---------------------------------------------------------------------------
output "subnet_ids" {
  description = "Map of subnet name → subnet OCID"
  value       = { for name, mod in module.subnet : name => mod.subnet_id }
}

output "subnet_cidrs" {
  description = "Map of subnet name → subnet CIDR block"
  value       = { for name, subnet in local.resolved_subnets : name => subnet.cidr_final }
}

output "nsg_ids" {
  description = "Map of NSG key -> NSG OCID for created Network Security Groups."
  value       = { for key, nsg_mod in module.nsg : key => nsg_mod.nsg_id }
}

output "all_services_cidr" {
  description = "CIDR block for 'All Services in Oracle Services Network' in the current region."
  value       = module.vcn.service_gateway_service_cidr
}