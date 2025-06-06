variable "compartment_id" {
    description = "The OCID of the compartment where the subnet will be created."
    type        = string
}

variable "tenancy_ocid" {
    description = "The OCID of the tenancy (root compartment)."
    type        = string
}

variable "vcn_id" {
    description = "The OCID of the VCN where the subnet will be created."
    type        = string
}
variable "cidr_block" {
    description = "The CIDR block for the subnet."
    type        = string
}
variable "name" {
    description = "Subnet name (DNS label-compliant)."
    type        = string
    validation {
        condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
        error_message = "The name must be 1-63 chars, start with a letter, end with a letter or digit, and contain only lowercase letters, digits, or hyphens."
    }
}

variable "availability_domain" {
  description = <<DESC
Full AD name (e.g. "qYkj:CA-MONTREAL-1-AD-1")  – OR –
short form "AD-1" / "AD-2" / "AD-3".
Leave empty/null to create a regional subnet.
DESC
  type     = string
  nullable = true
  default  = null
}

variable "gateway_type" {
  description = "Gateway type to route egress traffic through."
  type        = string
  default     = "ngw"
  validation {
    condition     = can(regex("^(igw|ngw|sgw|drg)$", var.gateway_type))
    error_message = "gateway_type must be one of: igw, ngw, sgw, drg."
  }
}

variable "env_name" {
    description = "Environment name for tagging."
    type        = string
}

variable "igw_id" {
    description = "The OCID of the Internet Gateway (if applicable)."
    type        = string
    default     = null
}

variable "ngw_id" {
    description = "The OCID of the NAT Gateway (if applicable)."
    type        = string
    default     = null
}

variable "sgw_id" {
    description = "The OCID of the Service Gateway (if applicable)."
    type        = string
    default     = null
}

variable "log_retention_duration" {
  description = "The number of days to retain flow logs"
  type        = number
  default     = 30
}

variable "flow_log_enabled" {
  description = "Whether flow logs are enabled for the subnet"
  type        = bool
  default     = true
}

variable "security_list_ids" {
    description = "List of security list OCIDs to associate with the subnet."
    type        = list(string)
    default     = []
  
}

variable "route_table_id" {
    description = "The OCID of the route table to associate with the subnet."
    type        = string
    nullable    = true
    default     = null  
}

variable "create_route_table" {
    description = "Whether to create a route table for the subnet."
    type        = bool
    default     = true
}

## Can be skipped if rt not created by subnet module
variable "all_services_cidr" {
    description = "The CIDR block for all services."
    type        = string
    nullable = true
    default = null
}

variable "create_log_group" {
  description = "Whether a log group should be created for this subnet."
  type        = bool
  default     = true
}

variable "network_security_group_ids" {
  description = "List of Network Security Group OCIDs to associate with the subnet."
  type        = list(string)
  default     = []
}

variable "drg_id" {
  description = "OCID of the DRG attachment (if gateway_type = drg)."
  type        = string
  default     = null
}
