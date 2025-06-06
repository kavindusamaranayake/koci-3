variable "compartment_id" { type = string }
variable "state_id" { type = string }

# Bastion
variable "await_cloudinit" {
  description = "Wait for cloud-init to finish before Terraform continues."
  type        = bool
  default     = false
}
variable "assign_dns" { type = bool }
variable "tenancy_id"          { type = string }          # new, required
variable "availability_domain" {
  description = "Optional AD name (qYqZ:REGION-AD-1 …). Leave empty to auto-select the first AD."
  type        = string
  default     = ""
}
variable "bastion_image_os_version" {type = string}
variable "image_id" {
  description = "Optional image OCID. Leave empty to auto-select the latest Oracle-Linux image that matches bastion_image_os_version."
  type        = string
  default     = ""
}
variable "is_public" { type = bool }
variable "nsg_ids" {
  description = "List of NSG OCIDs to attach to the primary VNIC."
  type        = list(string)
  default     = []
}
variable "shape" { type = map(any) }
variable "ssh_public_key" {
  description = "Public key to inject into opc user. Empty string → disable SSH."
  type        = string
  default     = ""
}
variable "subnet_id" { type = string }
variable "timezone" { type = string }
variable "upgrade" { type = bool }
variable "user" { type = string }

# +++ NEW ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
variable "instance_display_name" {
  description = "Override the Compute instance display name. "
  type        = string
  default     = ""
}

# +++ NEW ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
variable "hostname_label" {
  description = "Optional hostname label for the primary VNIC. Must be 1-63 characters, lowercase letters, digits or hyphens, and unique within the subnet. Leave empty to fall back to \"b-<state_id>\"."
  type        = string
  default     = ""
}
# +++ END ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Tags
variable "defined_tags" { type = map(string) }
variable "freeform_tags" { type = map(string) }
variable "tag_namespace" { type = string }
variable "use_defined_tags" { type = bool }

variable "vcn_cidrs" {
  description = "VCN CIDRs to advertise through Tailscale."
  type        = list(string)
  default     = []
}

variable "tailscale_auth_key" {
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_private_key" {
  description = "Private key used only when await_cloudinit = true. Leave empty when SSH is disabled."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tailscale_exit_node" {
  description = "Advertise this bastion as a Tailscale exit-node."
  type        = bool
  default     = false
}