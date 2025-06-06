variable "name" {
    type        = string
    description = "Name of the network security group."
}

variable "env_name" {
    type        = string
    description = "Environment name for tagging."
}

variable "compartment_id" {
    description = "The OCID of the compartment where the subnet will be created."
    type        = string
}
variable "vcn_id" {
    description = "The OCID of the VCN where the subnet will be created."
    type        = string
}

variable "rules" {
  type = list(object({
    direction      = string       # INGRESS or EGRESS
    protocol       = string       # 1 (ICMP), 6 (TCP), 17 (UDP), or other protocol number
    cidr           = string       # CIDR block or security group OCID
    cidr_type      = string       # "CIDR_BLOCK" or "SERVICE_CIDR_BLOCK" or "NETWORK_SECURITY_GROUP"
    port           = number       # Destination port number (for TCP/UDP)
    port_max       = optional(number) # Max destination port for a range (optional)
    source_port_min = optional(number) # Min source port (for EGRESS TCP/UDP only)
    source_port_max = optional(number) # Max source port (for EGRESS TCP/UDP only)
    icmp_type      = optional(number) # ICMP type (for ICMP protocol only)
    icmp_code      = optional(number) # ICMP code (for ICMP protocol only)
  }))
  description = "Map of rules for the network security group."
  default = []
}