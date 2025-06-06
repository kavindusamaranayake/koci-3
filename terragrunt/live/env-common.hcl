###############################################################################
# Common settings for all per-environment stacks
###############################################################################

# -------------------------------------------------------------------
# Inherit all settings (extra_arguments, generate blocks, …) from
# the repo-root stack definition in root.kocil
# -------------------------------------------------------------------

locals {
  root_config = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  root_dir    = dirname(find_in_parent_folders("root.hcl"))

  name_prefix  = "koci"     

  cni_type = "oci_vcn_native" #"calico" or "flannel"          

  environments_to_bootstrap = {
    "core-services" = "ca-montreal-1"
  }

  # relative path to the directory that contains root.kocil
  current_path_rel_to_root = path_relative_to_include("root")
  path_parts               = split("/", local.current_path_rel_to_root)

  # Derive the environment name from the folder that follows `envs/`
  #   live/envs/<env-name>/...  →  index 2  ===  <env-name>
  # Fallback to "core-services" if the path is shorter (e.g., during tests)
  env = try(local.path_parts[2], "core-services")

  
  doppler_project        = local.root_config.locals.doppler_project
  doppler_service_token  = coalesce(
    get_env("DOPPLER_SERVICE_TOKEN"),
    get_env("DOPPLER_TOKEN"),
    "placeholder-token" # Use same placeholder as root
  )

  # Determine if we are running an init command
  is_init_phase = get_terraform_command() == "init"

  # Fetch secrets - Conditionally skip during 'init'
  _doppler_json_output = local.is_init_phase || local.doppler_service_token == "placeholder-token" ? "{}" : try(run_cmd(
      "bash", "-c",
      # (added STDERR redirection **and** fallback echo so the command exits 0)
      "DOPPLER_TOKEN='${local.doppler_service_token}' doppler secrets download --no-file --format json --project ${local.doppler_project} --config ${local.env} 2>/dev/null || echo '{}'"
  ), "{}")

  _secret_map = jsondecode(local._doppler_json_output)

  # --- SAFE Lookups for Backend Config & Inputs ---

  # 1. Attempt the raw lookups (will be null during init)
  _raw_compartment_ocid = lookup(local._secret_map, "COMPARTMENT_OCID", null)
  _raw_tenancy_ocid = lookup(local._secret_map, "TENANCY_OCID", null)
  _raw_user_ocid = lookup(local._secret_map, "USER_OCID", null)
  _raw_region = lookup(local._secret_map, "REGION", null)
  _raw_private_key = lookup(local._secret_map, "PRIVATE_KEY", null)
  _raw_fingerprint = lookup(local._secret_map, "FINGERPRINT", null)
  _raw_tfstate_namespace = lookup(local._secret_map, "TFSTATE_NAMESPACE", null)
  _raw_tfstate_bucket = lookup(local._secret_map, "TFSTATE_BUCKET", null)
  _raw_tfstate_access_key = lookup(local._secret_map, "TF_STATE_ACCESS_KEY", null)
  _raw_tfstate_secret_key = lookup(local._secret_map, "TF_STATE_SECRET_KEY", null)

  # 2. Define final values with fallbacks using coalesce (will use placeholders during init)
  compartment_ocid = coalesce(
    local._raw_compartment_ocid,
    "ocid1.compartment.oc1..aaaaaaaajklnsyhmjt2tem4opqeqxv5n3njn5u5t6v6khiph3if5uso6pfoa"
  )
  tenancy_ocid = coalesce(local._raw_tenancy_ocid, "ocid1.tenancy.oc1..aaaaaaaauasokfuusmntkiyr3xqynfsvazqxr6s6lyj3swfbu7u6pdnra6aq")
  region = coalesce(local._raw_region, "ca-montreal-1")
  private_key = coalesce(local._raw_private_key, "placeholder-private-key")
  user_ocid = coalesce(local._raw_user_ocid, "ocid1.user.oc1..aaaaaaaa5wuhdts3ys2abun6mlmbvri56ooukocisdzbispy4t2tcymidlcb5q")
  fingerprint = coalesce(local._raw_fingerprint, "6a:da:98:6d:a9:e5:d6:bc:b7:89:74:1d:c8:e7:91:42")
  tfstate_namespace = coalesce(local._raw_tfstate_namespace, "yzzvc0uk5vox")
  tfstate_bucket = coalesce(local._raw_tfstate_bucket,
                           "${lower(local.name_prefix)}-${local.env}-${substr(local.region, 0, 2)}-init")
  access_key = coalesce(local._raw_tfstate_access_key, "d69f2395ce332944276e358a85ec06451cb11e2d")
  secret_key = coalesce(local._raw_tfstate_secret_key, "QwZecNhdDrt7UVfax4wD3DE/pZ4rrCHK09i+7ehLIAo=")

  # 3. Construct endpoint based explicitly on whether the *raw* namespace lookup succeeded (will use placeholder URL during init)
  tfstate_endpoint = (
    local._raw_tfstate_namespace == null ?
    "https://placeholder.init.fail" :
    "https://${local._raw_tfstate_namespace}.compat.objectstorage.${local.region}.oraclecloud.com"
  )

  # ──────────────────────────────────────────────────────────────────────
  # Doppler lookups for Remote State - with explicit placeholders for init/plan
  # These run BEFORE terraform apply, so they might fail on the first run.
  # The placeholders allow init/plan to proceed. Actual values are used after bootstrap.
  # NOTE: These individual lookups are now redundant because the bulk download
  #       above handles fetching these secrets more efficiently and robustly.
  #       They are kept here commented out for historical/debugging reference.
  # ──────────────────────────────────────────────────────────────────────
  # _doppler_tfstate_bucket = trimspace(run_cmd(
  #   "bash", "-c",
  #   # Try fetching the secret, return placeholder on error (e.g., secret not found)
  #   # Use a distinct placeholder name for clarity during initial runs.
  #   format("doppler secrets get TFSTATE_BUCKET --project %s --config %s --plain 2>/dev/null || echo 'placeholder-bucket-init'",
  #     local.root_config.locals.doppler_project,
  #     local.env # Use the derived environment name (e.g., core-services)
  #   )
  # ))
  # _doppler_tfstate_namespace = trimspace(run_cmd(
  #   "bash", "-c",
  #   format("doppler secrets get TFSTATE_NAMESPACE --project %s --config %s --plain 2>/dev/null || echo 'placeholder-namespace-init'",
  #     local.root_config.locals.doppler_project,
  #     local.env
  #   )
  # ))
  # Optional: Fetch compartment OCID here ONLY IF needed for something other than module inputs
  # Module inputs MUST use dependency outputs. This lookup is generally NOT needed here anymore.
  # _doppler_compartment_ocid = trimspace(run_cmd(
  #   "bash", "-c",
  #   format("doppler secrets get COMPARTMENT_OCID --project %s --config %s --plain 2>/dev/null || echo 'ocid1.compartment.oc1..placeholderinit'",
  #     local.root_config.locals.doppler_project,
  #     local.env
  #   )
  # ))

  # NOTE: `tfstate_bucket`, `tfstate_namespace`, `tfstate_endpoint`, `access_key`, `secret_key`
  # have already been defined earlier in this locals block using the bulk download method.
  # The individual "_doppler_tfstate_*" look-ups above are no longer necessary for defining
  # these values and have been commented out or removed to avoid "Attribute redefined" errors.

  # ---------------------------------------------------------------------
  # Common tags
  # • Prefer the map exported by root.kocil (locals.tags)
  # • Gracefully fall back to an empty map so init/CI never breaks
  # ---------------------------------------------------------------------
  common_tags = merge(
    try(local.root_config.locals.tags, {}),   # <- was .common_tags
    {
      Environment = local.env
    }
  )

  compartment_id = local.compartment_ocid
}

# Inputs block remains the same - it defines defaults if modules need them,
# but specific stacks override these with dependency outputs where necessary.
# inputs = {
#   compartment_id = local.compartment_ocid # Prefer dependency output in specific stacks
#   region         = local.region
#   common_tags    = local.common_tags
#   env_name       = local.env
# }

# ---------------------------------------------------------------------
# Remote State Configuration (OCI Object Storage - S3 Compatible)
# ---------------------------------------------------------------------
#remote_state {
#  backend = "s3"
#  config = {
#    # --- Bucket and Key ---
#    bucket = local.tfstate_bucket 
#    key = "${path_relative_to_include()}/terraform.tfstate"
#
#    # --- OCI S3 Compatibility Settings ---
#    region   = local.region       
#    endpoint = local.tfstate_endpoint 
#
#    # --- Credentials ---
#    # These are automatically picked up from the locals defined earlier
#    access_key = local.access_key 
#    secret_key = local.secret_key 
#
#    # --- S3 Backend Settings for OCI ---
#    skip_region_validation      = true # Necessary for OCI S3 compatibility
#    skip_credentials_validation = true # Recommended for robustness, esp. with placeholders
#    skip_metadata_api_check     = true # Avoids unnecessary checks for non-AWS S3
#    force_path_style            = true # OCI Object Storage typically requires path-style access
#  }
#  generate = {
#    path      = "backend.tf"
#    if_exists = "overwrite_terragrunt"
#  }
#}
