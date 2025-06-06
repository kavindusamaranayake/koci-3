###############################################################################
# Root-module variables for the Network stack
###############################################################################

variable "compartment_id" {
    description = "Compartment OCID where the VCN and sub-resources will be created."
    type        = string
}

variable "tenancy_ocid" {
  description = "The OCID of the tenancy (root compartment), required by the subnet module."
  type        = string
}

variable "vcn_cidr" {
    description = "Primary CIDR block of the VCN."
    type        = string
}

variable "vcn_dns_label" {
    description = "Custom DNS label for the VCN. Leave empty to derive one automatically from env_name."
    type        = string
    default     = ""                # ← make optional
}

variable "env_name" {
    description = "Environment name (used as a prefix for resource names)."
    type        = string
}

variable "common_tags" {
    description = "Free-form tags applied to all resources."
    type        = map(string)
    default     = {}
}

# --------------------------------------------------------------------
# Subnet definitions (same schema & validations that were in 00_variables.tf)
# --------------------------------------------------------------------
variable "subnets" {
  description = <<DESC
List of subnet objects, e.g.:

[
  {
    name         = "public"
    cidr         = "10.1.0.0/24"
    ad           = "AD-1"            # or "" for regional
    gateway_type = "igw"             # igw, ngw, or sgw
    nsg_keys     = ["bastion", "lb"] # Optional: Keys matching NSGs defined below
  },
  …
]
DESC

  type = list(object({
    # ─────────── Caller MUST give a name ───────────
    name         = string

    # ─────────── 1 of the following 3  ─────────────
    cidr         = optional(string)          # hard-coded CIDR (kept working)
    newbits      = optional(number)          # subnet size bits (à-la cidrsubnet)
    netnum       = optional(number)          # subnet number bits (à-la cidrsubnet)

    ad           = optional(string, "")      # "" ⇒ regional
    gateway_type = optional(string, "ngw")   # igw / ngw / sgw

    # extra sugar
    dns_label    = optional(string)
    create       = optional(string, "auto")  # auto • always • never
    nsg_keys     = optional(list(string), [])
  }))

  # -------------------------------------------------------------------------
  # Simplified validation – only ensure uniqueness (no overlaps test yet)
  # -------------------------------------------------------------------------
  validation {
    # keep only non-null CIDRs before comparing
    condition = (
      length(
        distinct(
          compact([for s in var.subnets : try(s.cidr, null)])
        )
      )
      ==
      length(
        compact([for s in var.subnets : try(s.cidr, null)])
      )
    )
    error_message = "Duplicate subnet CIDR(s) found – each explicit CIDR must be unique."
  }
}

variable "region" {
    description = "OCI region."
    type        = string
}

# Optional passthroughs for the VCN module
variable "nat_gateway_reserved_ip_id" {
  description = "Reserved public-IP OCID for the NAT Gateway (optional)."
  type        = string
  default     = null
}

variable "all_services_id" {
  description = "OCID of 'All Services in Oracle Services Network' (optional)."
  type        = string
  default     = null
}

variable "create_state_bucket" {
  description = "Whether this module should create the Object-Storage bucket that holds Terraform state."
  type        = bool
  default     = false       # ← default is "do NOT create"
}

###############################################################################
# Optional state-bucket parameters
#   – currently unused because the resource count is hard-coded to 0
###############################################################################
variable "namespace" {
  description = "Object-Storage namespace used for the Terraform state bucket (only relevant when create_state_bucket = true)."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Name of the Terraform state bucket (only relevant when create_state_bucket = true)."
  type        = string
  default     = ""
}

# --- ADDED: Variables for NSG Rules ---
variable "network_security_groups" {
  /*
   * When the caller passes {}, we'll auto-create an empty-rule NSG
   * for every subnet (see locals.autogen_nsgs in main.tf).
   *
   * Use `any` so Terraform no longer enforces that all map elements
   * share an identical object shape.  The consumer code just treats
   * the value as a map and iterates over it, so this is safe.
   */
  type    = any
  default = {}
}
# --- END ADDED ---