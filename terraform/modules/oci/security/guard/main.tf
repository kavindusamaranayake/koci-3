#################################################################
# 1. Enable Cloud Guard for the tenancy (conditionally)         #
#################################################################
resource "oci_cloud_guard_cloud_guard_configuration" "enable_cloud_guard" {
  count = var.enabled ? 1 : 0          # ← create only when enabled

  # Cloud Guard can only be configured in the root compartment (the tenancy)
  compartment_id   = var.tenancy_ocid
  reporting_region = coalesce(
    var.reporting_region,
    # data source is indexed because it also uses `count`
    data.oci_identity_region_subscriptions.home_region[0]
      .region_subscriptions[0].region_name
  )
  status           = "ENABLED"
}

# fetch home region (only if enabled)
data "oci_identity_region_subscriptions" "home_region" {
  count      = var.enabled ? 1 : 0
  tenancy_id = var.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = ["true"]
  }
}

############################################################
# 2. Security Zone itself (also conditional)               #
############################################################
resource "oci_cloud_guard_security_zone" "network_security_zone" {
  count       = var.enabled ? 1 : 0
  depends_on  = [oci_cloud_guard_cloud_guard_configuration.enable_cloud_guard]

  compartment_id        = var.compartment_id          # compartment that will be governed
  display_name          = "${var.env_name}-security-zone"
  description           = "Security zone to enforce network security policies"

  # first ACTIVE recipe that the data-source returns
  security_zone_recipe_id = data.oci_cloud_guard_security_recipes.security_zone_recipes[0].security_recipe_collection[0].items[0].id
}

# Get the default security-zone recipes (only if enabled)
data "oci_cloud_guard_security_recipes" "security_zone_recipes" {
  count          = var.enabled ? 1 : 0
  compartment_id = var.compartment_id
  # NOTE: Removed the filter that made the list empty.
  # If you really need to filter, first inspect the raw output
  # (`terraform console`) to find the correct attribute names/values.
}

