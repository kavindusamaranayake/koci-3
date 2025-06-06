variable "nsg_id" {
  type = string
}

variable "direction" {           # INGRESS | EGRESS
  type = string
}

variable "protocol" {            # 1, 6, 17, …
  type = string
}

variable "cidr" {
  type = string
}

variable "cidr_type" {           # CIDR_BLOCK | SERVICE_CIDR_BLOCK | NETWORK_SECURITY_GROUP
  type = string
}

variable "port" {
  type    = number
  default = null
}

variable "port_max" {
  type    = number
  default = null
}

variable "source_port_min" {
  type    = number
  default = null
}

variable "source_port_max" {
  type    = number
  default = null
}

variable "icmp_type" {
  type    = number
  default = null
}

variable "icmp_code" {
  type    = number
  default = null
}

variable "description" {
  type    = string
  default = null
} 