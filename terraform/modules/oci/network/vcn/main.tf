# --- Virtual Cloud Network (VCN) ---
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id

  # Use the full env-slug (e.g. koci-dev-vcn) for human-readable name
  display_name   = "${var.env_name}-vcn"

  cidr_blocks    = [var.vcn_cidr]
  dns_label      = local.dns_label_final  # lower-case, no hyphen, ≤15 chars

  freeform_tags = merge(var.common_tags, { "Name" = "${var.env_name}-vcn" })
}


### --- Internet Gateway (for public subnets) ---
resource "oci_core_internet_gateway" "igw" {
  count          = var.create_igw ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.env_name}-igw"
  vcn_id         = oci_core_vcn.main.id
  enabled        = true

  freeform_tags = merge(var.common_tags, { "Name" = "${var.env_name}-igw" })
}

# --- NAT Gateway (for private subnets needing outbound internet) ---
resource "oci_core_nat_gateway" "ngw" {
  count          = var.create_ngw ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.env_name}-ngw"
  vcn_id         = oci_core_vcn.main.id
  public_ip_id   = var.nat_gateway_reserved_ip_id # Optional: Use a reserved public IP
  freeform_tags  = merge(var.common_tags, { "Name" = "${var.env_name}-ngw" })
}

# ---------------------------------------------------------------------------
# Resolve the "All Services in Oracle Services Network" OCID when the caller
# did not supply it.
# ---------------------------------------------------------------------------
data "oci_core_services" "all" {
  # The service we need is always called
  #   "All .* Oracle Services Network"
  filter {
    name   = "name"
    values = ["All .* Oracle Services Network"]
    regex  = true
  }
}

locals {
  # Prefer the value passed in; otherwise look it up automatically
  # service_gateway_service_id = (
  #   length(trimspace(coalesce(var.all_services_id, ""))) > 0
  #     ? trimspace(var.all_services_id)
  #     : try(data.oci_core_services.all.services[0].id, null)
  # )

  # --- REVISED LOGIC (Attempt 2) ---
  # 1. Get the trimmed provided ID, defaulting to "" if null *without* coalesce
  # _trimmed_provided_id = trimspace(coalesce(var.all_services_id, "")) # <-- This caused the error
  _trimmed_provided_id = var.all_services_id != null ? trimspace(var.all_services_id) : ""

  # 2. Get the looked-up ID, defaulting to null if not found
  _looked_up_id        = try(data.oci_core_services.all.services[0].id, null)

  # 3. Coalesce: Use the provided ID only if it's non-empty, otherwise use the looked-up ID.
  #    (This part should be okay now that _trimmed_provided_id is calculated differently)
  service_gateway_service_id = coalesce(
    # Pass null if the trimmed provided ID is empty, otherwise pass the ID itself
    local._trimmed_provided_id == "" ? null : local._trimmed_provided_id,
    local._looked_up_id
  )
  # --- END REVISED LOGIC ---

  # --- NEW: Get the CIDR block for the service gateway target ---
  service_gateway_service_cidr = try(data.oci_core_services.all.services[0].cidr_block, null)
  # --- END NEW ---

  # Build DNS label from env_name-vcn: lower, remove hyphens, max-15
  auto_dns_label = substr(
    replace(lower("${var.env_name}-vcn"), "-", ""),
    0,
    15
  )

  dns_label_final = var.dns_label != "" ? var.dns_label : local.auto_dns_label
}

# --- Service Gateway (for private subnets needing access to Oracle services) ---
resource "oci_core_service_gateway" "sgw" {
  count          = var.create_sgw ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.env_name}-sgw"
  vcn_id         = oci_core_vcn.main.id

  services {
    service_id = local.service_gateway_service_id
  }

  freeform_tags = merge(var.common_tags, { "Name" = "${var.env_name}-sgw" })
}
## UNCOMMENT ONCE SECURITY POLICY IS DECIDED
# module "guard" {
#   source = "../../security/guard"
#   compartment_id = var.compartment_id
#   env_name       = var.env_name
#   vcn_id         = oci_core_vcn.main.id
# }

### --- Dynamic Routing Gateway --------------------------------------------
resource "oci_core_drg" "drg" {
  count          = var.create_drg ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.env_name}-drg"
  freeform_tags  = merge(var.common_tags, { "Name" = "${var.env_name}-drg" })
}

resource "oci_core_drg_attachment" "vcn" {
  count    = var.create_drg ? 1 : 0
  display_name = "${var.env_name}-drg-attach"
  drg_id       = oci_core_drg.drg[0].id
  vcn_id       = oci_core_vcn.main.id
}