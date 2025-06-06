output "rule_id" {
  description = "OCID of the NSG security rule that was created."
  value       = oci_core_network_security_group_security_rule.this.id
} 