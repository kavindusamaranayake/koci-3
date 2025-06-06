# -----------------------------------------------------------------------------
# Core Network-Security-Group
# -----------------------------------------------------------------------------
resource "oci_core_network_security_group" "this" {
  # count = var.enabled ? 1 : 0 # Removed count, module call should be conditional if needed

  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = var.env_name != "" ? "${var.env_name}-${var.name}-nsg" : "${var.name}-nsg"

  # Add tags if you have a common tags variable
  # freeform_tags = var.common_tags
}

resource "oci_core_network_security_group_security_rule" "rules" {
  # count = var.enabled ? length(var.rules) : 0 # Removed count
  for_each = { for idx, rule in var.rules : idx => rule }

  network_security_group_id = oci_core_network_security_group.this.id # Use .id directly
  direction                 = upper(each.value.direction)
  protocol                  = each.value.protocol
  description               = each.value.description
  stateless                 = each.value.is_stateless

  # Conditional attributes based on direction
  source           = each.value.direction == "INGRESS" ? each.value.source : null
  source_type      = each.value.direction == "INGRESS" ? each.value.source_type : null
  destination      = each.value.direction == "EGRESS" ? each.value.destination : null
  destination_type = each.value.direction == "EGRESS" ? each.value.destination_type : null

  # Dynamic blocks for protocol options
  dynamic "tcp_options" {
    for_each = each.value.tcp_options != null ? [each.value.tcp_options] : []
    content {
      dynamic "destination_port_range" {
        for_each = tcp_options.value.destination_port_range != null ? [tcp_options.value.destination_port_range] : []
        content {
          min = destination_port_range.value.min
          max = destination_port_range.value.max
        }
      }
      dynamic "source_port_range" {
        for_each = tcp_options.value.source_port_range != null ? [tcp_options.value.source_port_range] : []
        content {
          min = source_port_range.value.min
          max = source_port_range.value.max
        }
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.udp_options != null ? [each.value.udp_options] : []
    content {
      dynamic "destination_port_range" {
        for_each = udp_options.value.destination_port_range != null ? [udp_options.value.destination_port_range] : []
        content {
          min = destination_port_range.value.min
          max = destination_port_range.value.max
        }
      }
      dynamic "source_port_range" {
        for_each = udp_options.value.source_port_range != null ? [udp_options.value.source_port_range] : []
        content {
          min = source_port_range.value.min
          max = source_port_range.value.max
        }
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.icmp_options != null ? [each.value.icmp_options] : []
    content {
      type = icmp_options.value.type
      code = icmp_options.value.code
    }
  }
}
# --- END ADDED ---


# --- REMOVED ---
# If you have rules defined via separate resources, guard them as well
# resource "oci_core_network_security_group_security_rule" "egress" {
#   count              = var.enabled ? length(var.egress_rules) : 0
#   network_security_group_id = oci_core_network_security_group.this[0].id
#   # …
# }
# --- END REMOVED --- 