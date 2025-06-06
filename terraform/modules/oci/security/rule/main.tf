resource "oci_core_network_security_group_security_rule" "rule" {
  network_security_group_id = var.nsg_id
  direction                 = var.direction
  protocol                  = var.protocol
  
  # For Ingress Rules
  source = var.direction == "INGRESS" ? var.cidr : null
  source_type = var.direction == "INGRESS" ? var.cidr_type : null
  stateless = var.stateless

  # Destination (EGRESS only)
  destination      = var.direction == "EGRESS" ? coalesce(var.cidr, "0.0.0.0/0") : null
  destination_type = var.direction == "EGRESS" ? coalesce(var.cidr_type, "CIDR_BLOCK") : null

# Protocol-specific options
  dynamic "tcp_options" {
    for_each = var.protocol == "6" && var.port != null ? [1] : []
    content {
      dynamic "source_port_range" {
        for_each = var.direction == "EGRESS" && var.source_port_min != null ? [1] : []
        content {
          min = var.source_port_min
          max = var.source_port_max != null ? var.source_port_max : var.source_port_min
        }
      }
      
      dynamic "destination_port_range" {
        for_each = var.port != null ? [1] : []
        content {
          min = var.port
          max = var.port_max != null ? var.port_max : var.port
        }
      }
    }
  }
  
  dynamic "udp_options" {
    for_each = var.protocol == "17" && var.port != null ? [1] : []
    content {
      dynamic "source_port_range" {
        for_each = var.direction == "EGRESS" && var.source_port_min != null ? [1] : []
        content {
          min = var.source_port_min
          max = var.source_port_max != null ? var.source_port_max : var.source_port_min
        }
      }
      
      dynamic "destination_port_range" {
        for_each = var.port != null ? [1] : []
        content {
          min = var.port
          max = var.port_max != null ? var.port_max : var.port
        }
      }
    }
  }
  
  dynamic "icmp_options" {
    for_each = var.protocol == "1" && var.icmp_type != null ? [1] : []
    content {
      type = var.icmp_type
      code = var.icmp_code
    }
  }
}