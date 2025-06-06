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
# generate "oci_provider" {
#   path      = "provider.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "oci" {
#   tenancy_ocid = "${local.tenancy_ocid}"
#   user_ocid    = "${local.user_ocid}"
#   fingerprint  = "${local.fingerprint}"
#   private_key  = <<KEY
# ${local.private_key}
# KEY
#   region       = "${local.region}"
# }
# EOF
# }

generate "oci_provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "oci" {
  tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaaclenjvfd4xb37sr5mcduaygjpiklltchacalt2a3en2ay7m6wkiq"
  user_ocid    = "ocid1.user.oc1..aaaaaaaa5j6ljhi454az6v6cgjfhfhjgbev3sn32obdek2w62ac4omhvkdjq"
  fingerprint  = "8c:7c:56:af:65:de:84:a9:8f:80:ef:21:f6:6e:54:eb"
  private_key  = <<KEY
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCOHXLO2PMSNZYn
xQzkzg3AZBHUlTka1PtDxh+jDe7treyqW2GdgLDnqAyfX6XK0fmKZ1rhENl5JWZx
D2K9JbwcaqNX2GACPnIy9XLHecl7PNtrvPAY8uW1VhsaK/dNLcQ2S6Nj3NgghfOw
X1NZCqT5f33dIYfM9aFmv9UEb4V+hT97qliFEpPb5ud3opWl2dFf/vKHxC9aGhF3
OBOAc9qjJQHsTBjI8epE9G2USdt5wrtm+OotCzfQdvOhQFqX25RlfPRuNuAX17o1
SPPYN1WLXF2X3LHEql5rHmBASDrH3ZQXyebr87jF+rsWSL+V4ZQVYmrSy+hS9sIW
LeGL72clAgMBAAECggEAG1TWi6l1tf7QTf27qRVn16RnOXcpcFudpz8nPnijhtp4
NZs1ftENNMBBDTWb8RHI6DFQbRCMgpwKw5ut5aqoLt7jYzWd4VCZLeu+k1Z8xVLC
8El585JjUyioNbRW72Tp43dQiRgkCL06TKVIpktBxyoZzrlwIJ7s15H1KdE430f/
ruKquBOqwuwLCMxEH+LsOP8b/dTxHTYV7Bp+7vgP/01HZRAmGd2NBwtm7mAqXBGC
CAiMQBnLZkXZIVRwwokKkZ+gqru6tJqtVYTNTGlqQk02ArMKM4FIjM4vp9GAPb//
XEoCiP1NWjIui7wqA4AN6pSHSij7UwFU0DvI0JD0AQKBgQDF6n3X286juMmhBF7q
h3P9oUNIgTBBS6WHBNZLi0COpA+CC11ihTazHWP4t6Jda1eMzAVZoCmOapcXNN/F
RqV7+C6qHSAhGIXxx6pibC2mhxLv1qdHMzLFmNvvLf5kEIAb6tcf9NS0cLcF2b3Z
u6owrxtetl3BbvH1cMwVtoiqwQKBgQC30pvbB7Qo38mN2MCaYR5UhL0GdlnH0/nM
dCksbUyqfwR2+bie00vu/2vGeeE98zRhg5T9pdz1r0syUKQiyK9KA1Gn8XTg81k3
z1AHcenc7OY5MQ90/z0E1V9a7q4XugqT9ImCQNAU1fbq0ZIDBp1m67Y7gMLb++Qk
mf7moxNJZQKBgFQjRQ6ARo+5nhYSupsvrHLVnLn1GeOYWi1VNBj3gSFiw6kAVdnt
UfzBcN+qiZ73ZEfZ8ChS+3es/sCB3OOMDgvuzT/Kk/8d4suPm3KuFJYn9Df75C9T
p7DzNASxY+V8UkoMAxp1xftTs6sMDzbCHi8GMjeIhcEW/kvegRR1/hHBAoGAJNPz
Gby/YXkEXoDQhZ1zgCdf342SizBy2X1kSlxTgc0UzelWDavziJxvsUH12H2DPw4n
qXGzhR1riVcSq01doQxtLaJ4ciEO/NlyBSvTWMm1jjvABwaj6PX+tq8e/e3t9JqH
eisWBTag04bNJAINQvNyfRVc9MnQeWzI3thJIukCgYEAwO5+qdqLkQ3SArLD2yQv
okM30ppC4Or0GFTxTEuRIKD8gNKuRFaiOz87JASX8wcXkkR5JW1a8g0X3IzgLGVM
MIiDxCwo049NBeooFmoMuNIRsmXLn/FjyQc4Wrtom3BJeFEcR/XsCwT9hIgXxO7X
v9IDCjzkaH2ZrLIHyNuFxHY=
-----END PRIVATE KEY-----
KEY
  region       = "ca-montreal-1"
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