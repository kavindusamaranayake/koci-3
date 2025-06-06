resource "oci_core_network_security_group" "this" {
    compartment_id = var.compartment_id
    vcn_id         = var.vcn_id
    display_name   = "${var.env_name}-${var.name}-nsg"
}

module "nsg_rule" {
    source = "./rule"
    for_each = { for r in var.rules : r.name => r }
    nsg_id = oci_core_network_security_group.this.id
    direction = each.value.direction
    protocol = each.value.protocol
    cidr = each.value.cidr
    cidr_type = each.value.cidr_type
    port = each.value.port
    port_max = each.value.port_max
    source_port_min = each.value.source_port_min
    source_port_max = each.value.source_port_max
    icmp_type = each.value.icmp_type
    icmp_code = each.value.icmp_code
}