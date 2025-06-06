variable "enabled" {
  description = "Whether to create the Network Security Group resources."
  type        = bool
  default     = true   # keep current behaviour unless caller overrides
}

variable "name" {
  description = "Display name for the Network Security Group (will be prefixed with env_name if provided)."
  type        = string
}

variable "env_name" {
  description = "Optional environment name prefix for the NSG display name."
  type        = string
  default     = ""
}

variable "compartment_id" {
  description = "The OCID of the compartment where the NSG will be created."
  type        = string
}

variable "vcn_id" {
  description = "The OCID of the VCN where the NSG will be created."
  type        = string
}

variable "rules" {
  description = "A list of security rule objects to apply to the NSG."
  type = list(object({
    # Required
    direction        = string # INGRESS or EGRESS
    protocol         = string # "all", "6" (TCP), "17" (UDP), "1" (ICMP), etc.
    description      = optional(string, "Managed by Terraform")

    # Source/Destination (provide one set based on direction)
    source           = optional(string) # CIDR block or NSG OCID (for INGRESS)
    source_type      = optional(string, "CIDR_BLOCK") # CIDR_BLOCK, NETWORK_SECURITY_GROUP, SERVICE_CIDR_BLOCK (for INGRESS)
    destination      = optional(string) # CIDR block or NSG OCID (for EGRESS)
    destination_type = optional(string, "CIDR_BLOCK") # CIDR_BLOCK, NETWORK_SECURITY_GROUP, SERVICE_CIDR_BLOCK (for EGRESS)

    # Optional Port ranges (for TCP/UDP)
    tcp_options = optional(object({
      destination_port_range = optional(object({
        min = number
        max = number
      }))
      source_port_range = optional(object({
        min = number
        max = number
      }))
    }))
    udp_options = optional(object({
      destination_port_range = optional(object({
        min = number
        max = number
      }))
      source_port_range = optional(object({
        min = number
        max = number
      }))
    }))

    # Optional ICMP options
    icmp_options = optional(object({
      type = number
      code = optional(number)
    }))

    # Optional flags
    is_stateless = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.rules :
      (rule.direction == "INGRESS" && rule.source != null && rule.source_type != null) ||
      (rule.direction == "EGRESS" && rule.destination != null && rule.destination_type != null)
    ])
    error_message = "Rules must specify 'source'/'source_type' for INGRESS direction or 'destination'/'destination_type' for EGRESS direction."
  }
  validation {
    condition = alltrue([
      for rule in var.rules :
      (rule.protocol == "6" || rule.protocol == "17") || (rule.tcp_options == null && rule.udp_options == null)
    ])
    error_message = "tcp_options and udp_options can only be specified for TCP (6) or UDP (17) protocols."
  }
   validation {
    condition = alltrue([
      for rule in var.rules :
      (rule.protocol == "1") || (rule.icmp_options == null)
    ])
    error_message = "icmp_options can only be specified for ICMP (1) protocol."
  }
}

# --- REMOVED (or keep if needed for specific egress-only scenarios, but 'rules' is more flexible) ---
# variable "egress_rules" { ... }
# --- END REMOVED --- 