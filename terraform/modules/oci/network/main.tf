# ------------------------------------------------------------------
# Create / lookup the VCN – all subnet modules depend on this
# ------------------------------------------------------------------
module "vcn" {
  source  = "./vcn"

  # mandatory
  compartment_id = var.compartment_id
  env_name       = var.env_name
  vcn_cidr       = var.vcn_cidr
  dns_label = (
    var.vcn_dns_label == "" ?
    substr(
      replace(lower("${var.env_name}-vcn"), "-", ""), 0, 15
    )
    :
    substr(
      replace(lower(var.vcn_dns_label), "-", ""), 0, 15
    )
  )
  common_tags    = var.common_tags

  # optional / passthrough
  nat_gateway_reserved_ip_id = var.nat_gateway_reserved_ip_id
  all_services_id            = var.all_services_id

  # ── NEW : tell the vcn module which gateways to build ────────────────────
  create_igw = local.need_igw
  create_ngw = local.need_ngw
  create_sgw = local.need_sgw
  create_drg = local.need_drg
}

# --- ADDED: Create NSGs based on input variable ---
module "nsg" {
  for_each = local.autogen_nsgs

  source = "./nsg"

  name           = each.key
  env_name       = var.env_name
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id

  # NEW: fall back to an empty list when the caller did not define any rules
  rules          = try(each.value.rules, [])
}
# --- END ADDED ---

####################################################################
# Existing code – keep the subnet module exactly as it was
####################################################################
module "subnet" {
    for_each = {
      for k, v in local.resolved_subnets :
      k => v if v.create_final     # ← skip when create == "never"
    }
    source = "./subnet"
    name              = replace(each.value.name, "_", "-")
    compartment_id      = var.compartment_id
    tenancy_ocid        = var.tenancy_ocid
    vcn_id              = module.vcn.vcn_id
    cidr_block          = each.value.cidr_final
    availability_domain = each.value.ad
    gateway_type          = each.value.gateway_type
    igw_id             = module.vcn.igw_id
    ngw_id             = module.vcn.ngw_id
    sgw_id             = module.vcn.sgw_id
    env_name            = var.env_name
    all_services_cidr  = module.vcn.service_gateway_service_cidr
    drg_id             = module.vcn.drg_attachment_id

    # keep NSG mapping, but it now works even when some keys have no rules
    network_security_group_ids = [
      for key in each.value.nsg_keys : module.nsg[key].nsg_id
      if contains(keys(module.nsg), key)
    ]
}

# ─────────────────────────────────────────────────────────────
# 1)  Resolve / normalise subnet definitions
# ─────────────────────────────────────────────────────────────
locals {
  # Base /16 comes from var.vcn_cidr
  _vcn_cidr = var.vcn_cidr

  resolved_subnets = {
    for s in var.subnets :
    s.name => merge(s, {
      # Final CIDR
      cidr_final = coalesce(
        s.cidr,
        (
          alltrue([
            contains(keys(s),"newbits"),
            contains(keys(s),"netnum")
          ])
          ? cidrsubnet(local._vcn_cidr, s.newbits, s.netnum)
          : null
        )
      ),
      # DNS label (caller-supplied → auto → empty)
      dns_label_final = coalesce(
        s.dns_label,
        substr(replace(lower(s.name), "-", ""),0,15),
      ),
      # honour "create" flag – default is auto / always
      create_final = s.create == "never" ? false : true
    })
  }

  # ────────────────────────────────────────────────────────────
  # 2)  Build the final NSG map by merging defaults and inputs
  # ────────────────────────────────────────────────────────────
  autogen_nsgs = merge(
    # default: one empty-rule NSG per subnet key
    { for k in keys(local.resolved_subnets) : k => { rules = [] } },

    # caller-supplied NSGs (may override defaults or add new ones)
    var.network_security_groups
  )

  # ── NEW : does at least one subnet use the given gateway? ────────────────
  need_igw = length([for s in local.resolved_subnets : s if s.gateway_type == "igw"]) > 0
  need_ngw = length([for s in local.resolved_subnets : s if s.gateway_type == "ngw"]) > 0
  need_sgw = length([for s in local.resolved_subnets : s if s.gateway_type == "sgw"]) > 0
  need_drg = length([for s in local.resolved_subnets : s if s.gateway_type == "drg"]) > 0
}