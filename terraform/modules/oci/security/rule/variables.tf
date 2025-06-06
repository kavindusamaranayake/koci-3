variable "direction" {
  type        = string
  description = "Direction of traffic flow (INGRESS or EGRESS)"
}

variable "protocol" {
  type        = string
  description = "Protocol number (1 for ICMP, 6 for TCP, 17 for UDP, or other protocol number)"
}

variable "cidr" {
  type        = string
  description = "CIDR block or security group OCID"
}

variable "cidr_type" {
  type        = string
  description = "Type of CIDR (CIDR_BLOCK or SERVICE_CIDR_BLOCK or NETWORK_SECURITY_GROUP)"
}

variable "port" {
  type        = number
  description = "Destination port number (for TCP/UDP)"
}

variable "port_max" {
  type        = number
  default     = null
  description = "Max destination port for a range"
}

variable "source_port_min" {
  type        = number
  default     = null
  description = "Min source port (for EGRESS TCP/UDP only)"
}

variable "source_port_max" {
  type        = number
  default     = null
  description = "Max source port (for EGRESS TCP/UDP only)"
}

variable "icmp_type" {
  type        = number
  default     = null
  description = "ICMP type (for ICMP protocol only)"
}

variable "icmp_code" {
  type        = number
  default     = null
  description = "ICMP code (for ICMP protocol only)"
}

variable "nsg_id" {
  type        = string
  description = "The OCID of the network security group."
}

variable "stateless" {
  type        = bool
  default     = false
  description = "Whether the rule is stateless."
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the rule"
}