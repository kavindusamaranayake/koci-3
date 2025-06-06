variable "compartment_id" {
    description = "The OCID of the compartment where the subnet will be created."
    type        = string
}

variable "vcn_id" {
    description = "The OCID of the VCN where the subnet will be created."
    type        = string
}

variable "name" {
    description = "The name of the subnet."
    type        = string
  
}

variable "route_rules" {
  description = "List of route rules for this route table."
  type = list(object({
    destination        = string
    destination_type   = string
    network_entity_id  = string
    description        = optional(string)
  }))
}