# Export the AD (or null for regional subnets) so that callers can
# reference it as `module.subnet["<key>"].availability_domain`
output "availability_domain" {
  description = "Resolved availability domain of this subnet (null if regional)."
  value       = oci_core_subnet.this.availability_domain
} 