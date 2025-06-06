variable "compartment_id" {
  description = "The OCID of the compartment where network resources will be created."
  type        = string
}

variable "env_name" {
  description = "A name prefix for network resources (e.g., 'dev-us', 'prod-ca')."
  type        = string
}

variable "vcn_cidr" {
  description = "The primary CIDR block for the VCN."
  type        = string
}

variable "dns_label" {
  description = <<DESC
Optional custom DNS label for the VCN.

If empty, the module will derive one automatically from var.name
(hyphens stripped, max-15 chars) so that it always satisfies OCI rules:
  • 1-15 characters
  • starts with a letter
  • letters or digits only
DESC
  type    = string
  default = ""

  validation {
    condition     = var.dns_label == "" || can(regex("^[a-z][a-z0-9]{0,14}$", var.dns_label))
    error_message = "dns_label must be 1-15 chars, start with a letter, and contain only lowercase letters or digits."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}


variable "nat_gateway_reserved_ip_id" {
  description = "The OCID of the reserved public IP for the NAT Gateway."
  type        = string
  default     = null
}

variable "all_services_id" {
  description = "The OCID of all services for Service Gateway."
  type        = string
}

# ─── Gateway creation toggles (default keeps old behaviour = always) ───────
variable "create_igw" {
  description = "Create an Internet Gateway?"
  type        = bool
  default     = true
}

variable "create_ngw" {
  description = "Create a NAT Gateway?"
  type        = bool
  default     = true
}

variable "create_sgw" {
  description = "Create a Service Gateway?"
  type        = bool
  default     = true
}

variable "create_drg" {
  description = "Create a Dynamic Routing Gateway (DRG) + VCN attachment?"
  type        = bool
  default     = true
}