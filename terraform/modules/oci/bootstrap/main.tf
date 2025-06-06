###############################################################################
# Locals
###############################################################################
locals {
  # ----------------------------------------------------------------
  # one entry per environment with its own region & handy helpers
  # ----------------------------------------------------------------
  env_cfg = {
    for env_name, env_region in var.environments :
    lower(env_name) => {
      name         = env_name
      name_lower   = lower(env_name)
      region       = env_region
      region_short = substr(env_region, 0, 2)      # "ca", "us", …
      slug         = "${lower(env_name)}"
      #slug         = "${lower(var.name_prefix)}-${lower(env_name)}-${substr(env_region,0,2)}"

      #compartment_name = "${lower(var.name_prefix)}-${lower(env_name)}-${substr(env_region,0,2)}"
      # Fixed name for now
      compartment_name = "${lower(env_name)}"
    }
  }

  create_kms = var.create_kms_resources && var.kms_key_id == ""
  effective_kms_key_id = var.kms_key_id != "" ? var.kms_key_id : (
    local.create_kms ? one(oci_kms_key.bootstrap[*].id) : null
  )
}

###############################################################################
# Providers
###############################################################################

###############################################################################
# Tag namespace – look it up first; create only when missing
###############################################################################
data "oci_identity_tag_namespaces" "existing" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = [var.tag_namespace_name]
  }
}

########################  PROTECTED variant  ##################################
resource "oci_identity_tag_namespace" "ns_protected" {
  # allow_compartment_destroy = false  → maybe create namespace
  # allow_compartment_destroy = true   → never create in this branch
  count = var.allow_compartment_destroy ? 0 : (
    length(data.oci_identity_tag_namespaces.existing.tag_namespaces) == 0 ? 1 : 0
  )

  compartment_id = var.tenancy_ocid
  name           = var.tag_namespace_name
  description    = "Bootstrap tag namespace"
  freeform_tags  = var.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

########################  Unprotected variant  ###############################
resource "oci_identity_tag_namespace" "ns_unprotected" {
  # allow_compartment_destroy = true  → maybe create namespace (un-protected)
  # allow_compartment_destroy = false → never create in this branch
  count = var.allow_compartment_destroy ? (
    length(data.oci_identity_tag_namespaces.existing.tag_namespaces) == 0 ? 1 : 0
  ) : 0

  compartment_id = var.tenancy_ocid
  name           = var.tag_namespace_name
  description    = "Bootstrap tag namespace"
  freeform_tags  = var.common_tags
  # no lifecycle block → destroy allowed
}

##################### single ID all code can use ##############################
locals {
  tag_namespace_id = coalesce(
    try(data.oci_identity_tag_namespaces.existing.tag_namespaces[0].id, null),
    try(oci_identity_tag_namespace.ns_protected[0].id,  null),
    try(oci_identity_tag_namespace.ns_unprotected[0].id, null),
  )
}

###############################################################################
# Per-environment resources
###############################################################################
# ---------------------------------------------------------------------------
# Look up an already-existing compartment with the same name
# ---------------------------------------------------------------------------
data "oci_identity_compartments" "existing_env" {
  for_each       = local.env_cfg
  compartment_id = var.tenancy_ocid        
  access_level   = "ANY"

  filter {
    name   = "name"
    values = [each.value.compartment_name]
  }
}

# ---------------------------------------------------------------------------
# Create the compartment only when it doesn't already exist
###############################################################################

########################  PROTECTED variant  ##################################
resource "oci_identity_compartment" "env_protected" {
  for_each = {
    for k, v in local.env_cfg :
    k => v
    if var.allow_compartment_destroy == false
  }

  compartment_id = coalesce(var.parent_compartment_ocid, var.tenancy_ocid)
  name           = each.value.compartment_name
  description    = "Isolated compartment for ${each.value.name}"
  enable_delete  = true
  freeform_tags  = var.common_tags

  lifecycle {
    prevent_destroy = true     
  }

  timeouts {
    delete = "30m"  
  }
}

########################  UNprotected variant  ################################
resource "oci_identity_compartment" "env_unprotected" {
  for_each = {
    for k, v in local.env_cfg :
    k => v
    if var.allow_compartment_destroy == true &&
       length(data.oci_identity_compartments.existing_env[k].compartments) == 0
  }

  compartment_id = coalesce(var.parent_compartment_ocid, var.tenancy_ocid)
  name           = each.value.compartment_name
  description    = "Isolated compartment for ${each.value.name}"
  enable_delete  = true
  freeform_tags  = var.common_tags
  # ← no lifecycle block → destroy is permitted

  timeouts {
    delete = "30m"   # compartment deletion can be slow
  }
}

# ──────────────────────────────────────────────────────────────────────────── #
# Single source-of-truth for every environment's compartment OCID
# ──────────────────────────────────────────────────────────────────────────── #
locals {
  env_compartment_ids = {
    for k, v in local.env_cfg :
    k => coalesce(
      # existing compartment (already present before this run)
      try(data.oci_identity_compartments.existing_env[k].compartments[0].id, null),

      # brand-new protected compartment
      try(oci_identity_compartment.env_protected[k].id, null),

      # brand-new un-protected compartment
      try(oci_identity_compartment.env_unprotected[k].id, null)
    )
  }
}

resource "oci_identity_group" "tf" {
  for_each = {
    for k, v in local.env_cfg :
    k => v
    if length(data.oci_identity_groups.existing[k].groups) == 0
  }
  name           = "${each.value.name_lower}-tf-group"
  description    = "Terraform group ${each.value.name}"
  freeform_tags  = var.common_tags
}

resource "oci_identity_user" "tf" {
  for_each = {
    for k, v in local.env_cfg :
    k => v
    if length(data.oci_identity_users.existing[k].users) == 0
  }
  name           = "${each.value.name_lower}-tf-user"
  description    = "Terraform user ${each.value.name}"
  email          = "${each.value.name_lower}-tf@koci.com"
  freeform_tags  = var.common_tags
}

resource "oci_identity_user_group_membership" "m" {
  for_each = {
    for k, v in local.env_cfg :
    k => v
    if contains(keys(oci_identity_user.tf),  k) &&
       contains(keys(oci_identity_group.tf), k)
  }
  user_id  = local.tf_user_ids[each.key]
  group_id = local.tf_group_ids[each.key]
}

##############################################################################
# ALWAYS generate a fresh key-pair – one loop entry per environment
##############################################################################
resource "tls_private_key" "tf" {
  for_each  = local.env_cfg         
  algorithm = "RSA"
  rsa_bits  = 2048
}

##############################################################################
# Upload the public key for *every* environment's TF user
##############################################################################
resource "oci_identity_api_key" "tf" {
  for_each  = local.env_cfg
  user_id   = local.tf_user_ids[each.key]           
  key_value = tls_private_key.tf[each.key].public_key_pem

  lifecycle {
    # prevent the temporary loss of a key in case of replacement
    create_before_destroy = true
  }
}

# ────────────────────────────────────────────────────────────────────────────
#   Check if the <env>-tf-policy already exists
# ────────────────────────────────────────────────────────────────────────────
data "oci_identity_policies" "existing" {
  for_each       = local.env_cfg
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["${each.value.name_lower}-tf-policy"]
  }
}

# ────────────────────────────────────────────────────────────────────────────
#   Create/Update the single policy per environment with all required statements
#   (Handles both new and existing policies via Terraform's update mechanism)
# ────────────────────────────────────────────────────────────────────────────
resource "oci_identity_policy" "tf" {
  for_each = local.env_cfg

  compartment_id = var.tenancy_ocid # Policies granting compartment access reside in root
  name           = "${each.value.name_lower}-tf-policy"
  description    = "Consolidated Terraform permissions for the ${each.value.name} environment"

  # --- Updated & Consolidated Statements ---
  statements = [
    # --- Compartment Management ---
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage all-resources IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage compartments IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",

    # --- Network Management ---
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage virtual-network-family IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage load-balancers IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",

    # --- OKE Management ---
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage cluster-family IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",

    # --- Storage Management ---
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage volume-family IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage object-family IN COMPARTMENT id ${local.env_compartment_ids[each.key]}",

    "ALLOW GROUP ${each.value.name_lower}-tf-group TO read all-resources IN TENANCY",
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO use tag-namespaces IN TENANCY WHERE target.tag-namespace.name = '${var.tag_namespace_name}'",
    "ALLOW GROUP ${each.value.name_lower}-tf-group TO manage dynamic-groups IN TENANCY",

    # Explicitly allow managing network security groups (even though all-resources should cover it)
    "Allow group ${each.value.name_lower}-tf-group to manage network-security-groups in compartment id ${local.env_compartment_ids[each.key]}"
  ]

  freeform_tags = var.common_tags

  # Allow updates to the policy statements if they change
  lifecycle {
    ignore_changes = [
      # Ignore changes to defined_tags, description, freeform_tags if needed,
      # but allow statements to be updated.
    ]
  }
}

data "oci_objectstorage_namespace" "ns" {}

###############################################################################
# Bucket – one per environment
###############################################################################

resource "oci_objectstorage_bucket" "tfstate" {
  for_each = local.env_cfg

  compartment_id = local.env_compartment_ids[each.key]
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${each.value.slug}-tfstate"
  storage_tier   = "Standard"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
  kms_key_id     = local.effective_kms_key_id
  freeform_tags  = var.common_tags

  timeouts {
    delete = "30m"
  }
}

locals {
  tfstate_bucket_names = {
    for k, v in oci_objectstorage_bucket.tfstate : k => v.name
  }
}

###############################################################################
# Doppler secrets – build flat map
###############################################################################
locals {
  tf_user_ids = {
    for k, v in local.env_cfg :
    k => coalesce(
      try(data.oci_identity_users.existing[k].users[0].id, null),
      try(oci_identity_user.tf[k].id,                      null)
    )
  }

  tf_api_key_ids = {
    for k in keys(local.env_cfg) :
    k => coalesce(
      try(oci_identity_api_key.tf[k].id,                     null),
      try(data.oci_identity_api_keys.existing[k].api_keys[0].id, null)
    )
  }

  tf_api_key_fps = {
    for k in keys(local.env_cfg) :
    k => coalesce(
      try(oci_identity_api_key.tf[k].fingerprint,                     null),
      try(data.oci_identity_api_keys.existing[k].api_keys[0].fingerprint, null)
    )
  }

  tf_private_keys = { for k in keys(local.env_cfg) : k => try(tls_private_key.tf[k].private_key_pem, null) }

  # --------------------------------------------------------------------------
  # Deterministic flat map: <env>_<NAME> → { env_key, name, value }
  # --------------------------------------------------------------------------
  doppler_secrets_flat = merge([
    for env_key, env in local.env_cfg : {
      for name, raw_val in {
        ENVIRONMENT_NAME  = env.name
        COMPARTMENT_OCID  = local.env_compartment_ids[env_key]
        TENANCY_OCID      = var.tenancy_ocid
        USER_OCID         = local.tf_user_ids[env_key]
        FINGERPRINT       = local.tf_api_key_fps[env_key]
        REGION            = env.region
        PRIVATE_KEY       = local.tf_private_keys[env_key]
        TFSTATE_BUCKET    = local.tfstate_bucket_names[env_key]
        TFSTATE_NAMESPACE = data.oci_objectstorage_namespace.ns.namespace
        GROUP_OCID        = local.tf_group_ids[env_key]
        API_KEY_ID        = local.tf_api_key_ids[env_key]
      } :
      "${env_key}_${name}" => {
        env_key = env_key
        name    = name
        value   = tostring(coalesce(raw_val, "__PLACEHOLDER__"))
      }
    }
  ]...)
}

# --------------------------------------------------------------------------- #
# Single Doppler-secret resource                                              #
# --------------------------------------------------------------------------- #
resource "doppler_secret" "secrets" {
  for_each = local.doppler_secrets_flat

  project = var.doppler_project
  config  = doppler_config.env[each.value.env_key].name
  name    = each.value.name
  value   = each.value.value

  depends_on = [
    oci_identity_api_key.tf,
    doppler_config.env
  ]
}

###############################################################################
# Optional Vault & Key (created only when kms_key_id not supplied AND creation enabled)
###############################################################################
resource "oci_kms_vault" "bootstrap" {
  count          = local.create_kms ? 1 : 0
  compartment_id = var.tenancy_ocid
  display_name   = "tf-bootstrap-vault-${var.name_prefix}" # Added prefix for clarity
  vault_type     = "DEFAULT"
  freeform_tags  = var.common_tags
}

resource "oci_kms_key" "bootstrap" {
  count                = local.create_kms ? 1 : 0
  compartment_id       = var.tenancy_ocid
  display_name         = "tf-bootstrap-key-${var.name_prefix}" # Added prefix for clarity
  management_endpoint  = oci_kms_vault.bootstrap[0].management_endpoint
  protection_mode      = "HSM" # Consider changing to SOFTWARE if HSM limits are also an issue

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  # Consider setting this based on var.kms_rotation_period_days if needed
  is_auto_rotation_enabled = false

  freeform_tags = var.common_tags
}

####################  Object-Storage ⇆ KMS permission  ########################
# Allow the regional Object-Storage service principal to use keys in tenancy
###############################################################################
resource "oci_identity_policy" "objectstorage_kms" {
  count          = local.create_kms ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-objectstorage-kms"
  description    = "Permit Object Storage to use the bootstrap KMS key"

  statements = [
     "ALLOW SERVICE objectstorage-${lower(var.region)} TO use keys IN TENANCY where target.key.id = '${oci_kms_key.bootstrap[0].id}'"
  ]

  freeform_tags = var.common_tags

  lifecycle {
    prevent_destroy = false
  }
}

###############################################################################
# Doppler – create an ENVIRONMENT per environment slug (e.g., dev-core-services)
###############################################################################
resource "doppler_environment" "env" {
  for_each = local.env_cfg
  project  = var.doppler_project
  slug     = each.value.name_lower 
  name     = each.value.name       
}

###############################################################################
# Doppler – create a CONFIG per environment, linked to the Environment above
###############################################################################
resource "doppler_config" "env" {
  for_each = local.env_cfg
  project     = var.doppler_project
  environment = doppler_environment.env[each.key].slug
  name        = each.value.name_lower # Keep config name as the lower-case slug

  depends_on = [
    doppler_environment.env
  ]
}

# ────────────────────────────────────────────────────────────────────────────
#  See if TF group / user already exist
# ────────────────────────────────────────────────────────────────────────────
data "oci_identity_groups" "existing" {
  for_each       = local.env_cfg
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["${each.value.name_lower}-tf-group"]
  }
}

data "oci_identity_users" "existing" {
  for_each       = local.env_cfg
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["${each.value.name_lower}-tf-user"]
  }
}

locals {
  tf_group_ids = {
    for k, v in local.env_cfg :
    k => coalesce(
      try(data.oci_identity_groups.existing[k].groups[0].id, null),
      try(oci_identity_group.tf[k].id,                     null)
    )
  }

}

data "oci_identity_api_keys" "existing" {
  for_each = local.env_cfg
  user_id  = local.tf_user_ids[each.key]
} 