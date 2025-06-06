data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

# ------------------------------------------------------------------
# Default security-list for the parent VCN (used when user passes none)
# ------------------------------------------------------------------
data "oci_core_vcn" "this" {
  vcn_id = var.vcn_id
}

locals {
  # Key map            { "AD-1" = "qYkj:CA-MONTREAL-1-AD-1", … }
  ad_name_map = {
    for ad in data.oci_identity_availability_domains.all.availability_domains :
    regex("AD-[0-9]+$", ad.name) => ad.name
  }

  # Trim once, reuse everywhere
  _trimmed_ad = var.availability_domain == null ? "" : trimspace(var.availability_domain)

  # ─── Final value that feeds the subnet resource ──────────────────────────
  resolved_availability_domain = (
    local._trimmed_ad == ""
      ? null
      : lookup(local.ad_name_map,
               upper(local._trimmed_ad),          # expand short form
               local._trimmed_ad)                 # or keep given value
  )

  # create a safe DNS label from the subnet name
  # e.g. "private-oke" → "privateoke"
  dns_label_final = substr(replace(lower(var.name), "-", ""), 0, 15)

  security_list_ids_final = (
    var.security_list_ids == null || length(var.security_list_ids) == 0
      ? [data.oci_core_vcn.this.default_security_list_id]  
      : var.security_list_ids                         
  )
}

###############################################################################
# Subnet
###############################################################################
resource "oci_core_subnet" "this" {
    compartment_id      = var.compartment_id
    vcn_id              = var.vcn_id
    cidr_block          = var.cidr_block
    display_name          = "${var.env_name}-${var.name}"
    dns_label             = local.dns_label_final
    prohibit_public_ip_on_vnic = var.gateway_type == "igw" ? false : true
    route_table_id        = var.create_route_table ? module.rt[0].route_table_id : var.route_table_id
    security_list_ids     = local.security_list_ids_final

    #network_security_group_ids = var.network_security_group_ids

    availability_domain        = local.resolved_availability_domain
}

module "rt" {
  # Plan-safe: only depends on a static variable
  count           = var.create_route_table ? 1 : 0
  source          = "../routing"
  compartment_id  = var.compartment_id
  vcn_id          = var.vcn_id
  name            = "${var.env_name}-${var.name}-rt"

  route_rules = concat(
    [
      {
        destination        = var.gateway_type == "sgw" ? coalesce(var.all_services_cidr, "ERROR_SERVICE_CIDR_IS_NULL") : "0.0.0.0/0"
        destination_type   = var.gateway_type == "sgw" ? "SERVICE_CIDR_BLOCK" : "CIDR_BLOCK"
        network_entity_id = (
          var.gateway_type == "ngw" ? var.ngw_id :
          var.gateway_type == "sgw" ? var.sgw_id :
          var.igw_id
        )
      }
    ],
    (var.gateway_type == "ngw" && var.sgw_id != null) ? [
      {
        destination        = var.all_services_cidr                       # e.g.  oci-yyz-services-cidr
        destination_type   = "SERVICE_CIDR_BLOCK"
        network_entity_id  = var.sgw_id
        description        = "OCI services via Service-Gateway"
      }
    ] : []
  )
}


# --- Log Group for Flow Logs ---
resource "oci_logging_log_group" "subnet_log_group" {
    count = var.create_log_group ? 1 : 0
    compartment_id = var.compartment_id
    display_name   = "${var.name}-log-group"
    description    = "Log group for subnet flow logs"
}

# --- Flow Log for Subnet ---
# create only when *both* flags are true
resource "oci_logging_log" "subnet_flow_log" {
    count            = (var.flow_log_enabled && var.create_log_group) ? 1 : 0
    display_name       = "${var.env_name}-${var.name}-flow-log"
    log_group_id       = oci_logging_log_group.subnet_log_group[count.index].id
    log_type           = "SERVICE"
    is_enabled         = true
    retention_duration = var.log_retention_duration

    configuration {
        source {
            category    = "all"
            resource    = oci_core_subnet.this.id
            service     = "flowlogs"
            source_type = "OCISERVICE"
        }
        compartment_id = var.compartment_id
    }
}