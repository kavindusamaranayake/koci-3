# Create a single NSG rule.  All values arrive from the parent module.

resource "oci_core_network_security_group_security_rule" "this" {
  network_security_group_id = var.nsg_id
  direction                 = upper(var.direction)  # INGRESS | EGRESS
  protocol                  = var.protocol

  dynamic "tcp_options" {
    for_each = (var.protocol == "6" && var.port != null) ? [1] : []
    content {
      destination_port_range {
        min = var.port
        max = coalesce(var.port_max, var.port)
      }
      source_port_range {
        min = var.source_port_min
        max = var.source_port_max
      }
    }
  }

  dynamic "udp_options" {
    for_each = (var.protocol == "17" && var.port != null) ? [1] : []
    content {
      destination_port_range {
        min = var.port
        max = coalesce(var.port_max, var.port)
      }
      source_port_range {
        min = var.source_port_min
        max = var.source_port_max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = (var.protocol == "1" && var.icmp_type != null) ? [1] : []
    content {
      type = var.icmp_type
      code = var.icmp_code
    }
  }

  destination      = var.cidr
  destination_type = var.cidr_type
  description      = var.description
} 