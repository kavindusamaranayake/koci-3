output nsg_id {
    description = "The OCID of the network security group"
    value       = oci_core_network_security_group.this.id
}