variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "env_name" {
  description = "Name for the load balancer"
  type        = string
}

variable "shape" {
  description = "Load balancer shape"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet OCIDs for the load balancer"
  type        = list(string)
}

variable "is_private" {
  description = "Whether LB is private or public"
  type        = bool
  default     = false
}

variable "backend_ips" {
  description = "List of backend IP addresses"
  type        = list(string)
}

variable "backend_set_name" {
  description = "Backend set name"
  type        = string
  default     = "app-backendset"
}

variable "certificate_id" {
  description = "OCID of the SSL certificate (optional)"
  type        = string
  default     = ""
}

variable "certificate_name" {
  description = "Certificate name in the LB certificate store"
  type        = string
  default     = "default-cert"
}

variable "waf_policy_id" {
  description = "OCID of the WAF policy (optional)"
  type        = string
  default     = ""
}

variable "nsg_ids" {
  description = "List of NSG OCIDs for the load balancer"
  type        = list(string)
  default     = []
}

variable "vcn_id" {
  description = "VCN OCID"
  type        = string
  
}