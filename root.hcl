# =========================================================================== #
# Root-level Terragrunt                                                          #
# – inject OCI & Doppler providers                                              #
# – expose tenancy-wide inputs to all children                                  #
# – driven by a Doppler **Service-Account** token                               #
# =========================================================================== #

locals {
  # -------------------------------------------------------------------------
  # Doppler context
  #   • project is still shared tenancy-wide
  #   • config is now supplied via the DOPPLER_CONFIG env-var
  # -------------------------------------------------------------------------
  doppler_project = "oci-infra"

  doppler_config = trimspace(get_env("DOPPLER_CONFIG", ""))

  doppler_service_token = coalesce(
    get_env("DOPPLER_SERVICE_TOKEN"),
    get_env("DOPPLER_TOKEN"),
    "placeholder-token"            
  )

  is_init_phase = get_terraform_command() == "init"

  
  should_download_doppler = (
    !local.is_init_phase                                      &&
    local.doppler_service_token != "placeholder-token"        &&
    length(trimspace(local.doppler_config)) > 0
  )

  _doppler_json = local.should_download_doppler ? try(
    run_cmd(
      "bash", "-c",
      local.doppler_config != "" ?
        format(
          "DOPPLER_TOKEN='%s' doppler secrets download --no-file --format json --project %s --config %s",
          local.doppler_service_token,
          local.doppler_project,
          local.doppler_config
        )
      :
        format(
          "DOPPLER_TOKEN='%s' doppler secrets download --no-file --format json --project %s",
          local.doppler_service_token,
          local.doppler_project
        )
    ),
    "{}"
  ) : "{}"

  _secret_map = jsondecode(local._doppler_json)

  
  tenancy_ocid = coalesce(
    (lookup(local._secret_map, "TENANCY_OCID", "") != "" ?
        lookup(local._secret_map, "TENANCY_OCID", "") : null),
    local.empty_to_null.tenancy_env,
    "ocid1.tenancy.oc1..dummy"
  )

  user_ocid = coalesce(
    (lookup(local._secret_map, "USER_OCID", "") != "" ?
        lookup(local._secret_map, "USER_OCID", "") : null),
    local.empty_to_null.user_env,
    "placeholder-user-ocid"
  )

  fingerprint = coalesce(
    (lookup(local._secret_map, "FINGERPRINT", "") != "" ?
        lookup(local._secret_map, "FINGERPRINT", "") : null),
    local.empty_to_null.fp_env,
    "placeholder-fingerprint"
  )

  private_key = coalesce(
    (lookup(local._secret_map, "PRIVATE_KEY", "") != "" ?
        lookup(local._secret_map, "PRIVATE_KEY", "") : null),
    local.empty_to_null.pkey_env,
    <<KEY
-----BEGIN RSA PRIVATE KEY-----
placeholder
-----END RSA PRIVATE KEY-----
KEY
  )

  # -------------------------------------------------------------------------
  # Final OCI region
  #   1. Doppler secret  REGON
  #   2. env-var        OCI_REGION
  #   3. placeholder    (compile-time fallback)
  # -------------------------------------------------------------------------
  region = coalesce(
    (lookup(local._secret_map, "REGION", "") != "" ?
       lookup(local._secret_map, "REGION", "") : null),
    trimspace(get_env("OCI_REGION", "")),
    "ca-montreal-1" #"placeholder-region"
  )

  # -----------------------------------------------------------------------
  # S3-compatible (OCI Object Storage) credentials
  #   • values come from the Doppler secret blob when available
  #   • fall back to env-vars
  #   • finally fall back to hard placeholders so that init/plan never fails
  # -----------------------------------------------------------------------
  access_key = coalesce(
    (lookup(local._secret_map, "TF_STATE_ACCESS_KEY", "") != "" ?
      lookup(local._secret_map, "TF_STATE_ACCESS_KEY", "") : null),
    local.empty_to_null.aws_access_key_env,
    "placeholder-access-key"
  )

  secret_key = coalesce(
    (lookup(local._secret_map, "TF_STATE_SECRET_KEY", "") != "" ?
      lookup(local._secret_map, "TF_STATE_SECRET_KEY", "") : null),
    local.empty_to_null.aws_secret_key_env,
    "placeholder-secret-key"
  )

  # -----------------------------------------------------------------------
  # Default tags
  # -----------------------------------------------------------------------
  tags = {
    ManagedBy = "koci-Terraform"
  }

  ######### helper ##############################################################
  # turn "" into null so coalesce() works as intended
  # This map reads env vars safely (defaulting to "") and converts "" to null.
  empty_to_null = { for k, v in {
    tenancy_env            = trimspace(get_env("TENANCY_OCID", "")),
    user_env               = trimspace(get_env("USER_OCID", "")),
    fp_env                 = trimspace(get_env("FINGERPRINT", "")),
    pkey_env               = trimspace(get_env("PRIVATE_KEY", "")),
    region_env             = trimspace(get_env("REGION", "")),

    aws_access_key_env     = trimspace(get_env("TF_STATE_ACCESS_KEY", "")),
    aws_secret_key_env     = trimspace(get_env("TF_STATE_SECRET_KEY", "")),
  } : k => (v == "" ? null : v) }
  # End of empty_to_null map definition
  ######### /helper #############################################################
} # End of the main locals block

# ---------------------------------------------------------------------------
# Inject OCI provider - Uses safe locals (placeholders during init)
# ---------------------------------------------------------------------------
generate "oci_provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "oci" {
  tenancy_ocid = "${local.tenancy_ocid}"
  user_ocid    = "${local.user_ocid}"
  fingerprint  = "${local.fingerprint}"
  private_key  = <<KEY
${local.private_key}
KEY
  region       = "${local.region}"
}
EOF
}

# ---------------------------------------------------------------------------
# Inject Doppler provider - Uses safe local (placeholder token during init)
# ---------------------------------------------------------------------------
generate "doppler_provider" {
  path      = "provider-doppler.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "doppler" {
  # Pass null if token is placeholder, otherwise pass the real token
  doppler_token = "${local.doppler_service_token}" == "placeholder-token" ? null : "${local.doppler_service_token}"
}
EOF
}

# ---------------------------------------------------------------------------
# Inputs - Use safe locals (placeholders during init)
# ---------------------------------------------------------------------------
inputs = {
  tenancy_ocid    = local.tenancy_ocid
  region          = local.region
  doppler_project = local.doppler_project # Static
  # Pass common tags safely
  common_tags     = local.tags
}

# ---------------------------------------------------------------------------
# Provider constraints
# ---------------------------------------------------------------------------
generate "required_providers" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = "<= 1.11.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.35"
    }
    doppler = {
      source  = "dopplerhq/doppler"
      version = "~> 1.3"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2.0"
    }
    local = {
      source = "hashicorp/local"
      version = "= 2.5.2"
    }
  }
}
EOF
}

# 2. Create ~/.aws/credentials on-the-fly
generate "aws_credentials" {
  path      = "~/.aws/credentials"
  if_exists = "overwrite"

  contents  = <<EOF
[default]
aws_access_key_id     = ${local.access_key}
aws_secret_access_key = ${local.secret_key}
EOF
}

# ---------------------------------------------------------------------------
# vars_root generator
# ---------------------------------------------------------------------------
generate "vars_root" {
  path      = "vars_root.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# File generated by Terragrunt root.kocil
# (intentionally left blank – variables are declared in each child module)
EOF
}

# ---------------------------------------------------------------------------
# Pass shared variables (-var=…) to **every** child Terraform module
# ---------------------------------------------------------------------------
terraform {
  extra_arguments "root_vars" {
    commands  = get_terraform_commands_that_need_vars()
    # keep the other -var arguments that are already here …
    arguments = concat(
      (
        local.region != "placeholder-region"
        ? ["-var=region=${local.region}"]
        : []
      ),
    )
  }
} 