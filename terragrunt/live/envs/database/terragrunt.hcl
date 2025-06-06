# ─── inherit env-common ──────────────────────────────────────────────────
include "common" {
  path   = find_in_parent_folders("env-common.hcl")
  expose = true
}

# ─── dependency: network (subnets, NSGs, VCN CIDR) ──────────────────────
dependency "network" {
  config_path = "../network"

  # Use mock values until the network layer has been applied
  mock_outputs = {
    # ── added "data" subnet and matching AD map ────────────────────────────
    subnet_ids                   = {
      bastion = "ocid1.subnet.oc1..mock_bastion"
      data    = "ocid1.subnet.oc1..mock_data"
    }
    #subnet_availability_domains  = {
    #  bastion = "phx-ad-1"
    #  data    = "phx-ad-1"
    #}
    nsg_ids        = { bastion = "ocid1.networksecuritygroup.oc1..mock" }
    vcn_cidr_block = "10.2.0.0/16"
  }
}

terraform {
  source = "."

  after_hook "push_mysql_creds_to_doppler" {
    commands     = ["apply", "apply-all"]
    run_on_error = false
    execute = [
      "sh", "-c", <<-EOT
# Check if secret exists before trying to set it
if ! DOPPLER_PROJECT='${local.doppler_project}' DOPPLER_CONFIG='${local.env}' \
     doppler secrets get MYSQL_DB_PASSWORD --plain >/dev/null 2>&1; then
  # fetch value that Terraform just generated & output
  MYSQL_DB_PASSWORD="$(terraform output -raw mysql_admin_password)"
  DOPPLER_PROJECT='${local.doppler_project}' DOPPLER_CONFIG='${local.env}' doppler secrets set \
    MYSQL_DB_USERNAME='${local.mysql_admin_username}' \
    MYSQL_DB_PASSWORD="$${MYSQL_DB_PASSWORD}" \
    --silent
else
  echo "MySQL credentials already exist in Doppler for project '${local.doppler_project}', config '${local.env}'. Skipping update."
fi
EOT
    ]
  }

  # ───────────────────────────────────────────────────────────────────────
  # After-apply hook ‑ push freshly-generated credentials to Doppler
  # ───────────────────────────────────────────────────────────────────────
  after_hook "push_app_db_creds_to_doppler" {
    commands     = ["apply", "apply-all"]
    run_on_error = false
    execute = [
      "bash", "-c", <<-EOT
      set -eo pipefail

      export DOPPLER_PROJECT='${local.doppler_project}'
      export DOPPLER_CONFIG='${local.env}'

      echo "Pushing DB credentials to Doppler project=${local.doppler_project} config=${local.env}…"

      # ---------------------------------------------------------------------
      # Helper: always overwrite a secret
      # ---------------------------------------------------------------------
      doppler_set() {
        local key="$1"
        local value="$2"
        doppler secrets set "$key=$value" --silent
        echo "✓ Secret $key updated."
      }

      # ---------------------------------------------------------------------
      # Resolve endpoints & admin password from Terraform outputs
      # ---------------------------------------------------------------------
      AUTH_HOST="$(terraform output -raw auth_server_db_endpoint 2>/dev/null || echo "")"
      MAIN_HOST="$(terraform output -raw main_api_db_endpoint   2>/dev/null || echo "")"
      DB_PASSWORD="$(terraform output -raw mysql_admin_password)"
      DB_USER="admin"

      # ---------------------------------------------------------------------
      # Build JSON payloads without jq
      # ---------------------------------------------------------------------
      build_payload() {
        # args: user pass host clusterId dbName
        printf '{"username":"%s","password":"%s","host":"%s","port":"3306","dbClusterIdentifier":"%s","database":"%s","maxPoolSize":"10","poolName":"MySQLAuthServerCP","autoCommit":"true","connectionTimeout":"60000","idleTimeout":"600000","maxLifetime":"1800000"}' \
               "$1" "$2" "$3" "$4" "$5"
      }

      AUTH_PAYLOAD="$(build_payload "$DB_USER" "$DB_PASSWORD" "$AUTH_HOST" "${local.authserver_cluster_identifier}" "${local.authserver_db_name}")"
      MAIN_PAYLOAD="$(build_payload "$DB_USER" "$DB_PASSWORD" "$MAIN_HOST" "${local.main_api_cluster_identifier}" "${local.main_api_db_name}")"

      doppler_set AUTH_SERVER_MYSQL_RO "$AUTH_PAYLOAD"
      doppler_set AUTH_SERVER_MYSQL_RW "$AUTH_PAYLOAD"
      doppler_set SERVICES_MYSQL_RO     "$MAIN_PAYLOAD"
      doppler_set SERVICES_MYSQL_RW     "$MAIN_PAYLOAD"
      EOT
    ]
  }
}


# ─── locals ──────────────────────────────────────────────────────────────
locals {
  # Reuse settings already defined in root/env-common and turn them into a slug
  # ex:  koci-dev-ca
  env_slug       = "${include.common.locals.name_prefix}-${include.common.locals.env}-${substr(include.common.locals.region, 0, 2)}"

  # -------------------------------------------------------------------------
  # Doppler context
  # -------------------------------------------------------------------------
  doppler_project = include.common.locals.doppler_project

  # The service-token linked to this layer has access to the "stg" config,
  # not "database", so force the environment override here.
  env             = "stg"

  # ── MySQL credentials: use Doppler value or create on first apply ───────
  _doppler_mysql_username_cmd = format(
    "DOPPLER_TOKEN='%s' doppler secrets get MYSQL_DB_USERNAME --project '%s' --config '%s' --plain 2>/dev/null || echo ''",
    include.common.locals.doppler_service_token, # Use the token from common locals
    local.doppler_project,
    local.env,
  )
  _doppler_mysql_password_cmd = format(
    "DOPPLER_TOKEN='%s' doppler secrets get MYSQL_DB_PASSWORD --project '%s' --config '%s' --plain 2>/dev/null || echo ''",
    include.common.locals.doppler_service_token, # Use the token from common locals
    local.doppler_project,
    local.env,
  )
  # Execute commands only if not in init phase
  _doppler_mysql_username = include.common.locals.is_init_phase ? "" : trimspace(run_cmd("bash", "-c", local._doppler_mysql_username_cmd))
  _doppler_mysql_password = include.common.locals.is_init_phase ? "" : trimspace(run_cmd("bash", "-c", local._doppler_mysql_password_cmd))

  mysql_admin_username = length(local._doppler_mysql_username) > 0 ? local._doppler_mysql_username : "admin"

  # Common tags from includes
  common_tags = merge(
      include.common.locals.common_tags, # Get base tags from env-common
      {
          # Add/override specific tags for this module if needed
          Service = "database"
      }
  )

  # ── Per-database identifiers & common connection-pool settings ─────────────
  authserver_db_name            = "authserver-db"
  authserver_cluster_identifier = "koci-core-services-auth-server-db"

  main_api_db_name              = "main-api-db"
  main_api_cluster_identifier   = "koci-core-services-db-cluster"

  connection_pool_defaults = {
    maxPoolSize       = "10"
    poolName          = "MySQLAuthServerCP"
    autoCommit        = "true"
    connectionTimeout = "60000"
    idleTimeout       = "600000"
    maxLifetime       = "1800000"
  }
}

###############################################################################
# 1. inputs – now also pass tenancy_ocid                                       #
###############################################################################
inputs = {
  compartment_id = include.common.locals.compartment_ocid
  subnet_id      = dependency.network.outputs.subnet_ids["data"]
  tenancy_ocid   = include.common.locals.tenancy_ocid

  env_name       = local.env_slug
  admin_username = local.mysql_admin_username

  # ---------------------------------------------------------------------------
  # Switch to the E-CPU family (ref: https://docs.oracle.com/en-us/iaas/mysql-
  # database/doc/supported-shapes.html).  `MySQL.4` is the closest equivalent
  # to the previously-used "Standard" shapes.
  # ---------------------------------------------------------------------------
  shape_name            = "MySQL.4"
  mysql_version         = "8.4.0"

  # HeatWave remains disabled
  enable_heatwave_cluster = false
  heatwave_cluster        = null

  common_tags   = local.common_tags
}

###############################################################################
# 2. generate "databases" – add AD data source & use it in module calls
###############################################################################
generate "databases" {
  path      = "databases.tf"
  if_exists = "overwrite_terragrunt"

  contents  = <<EOF
################################################################################
#  Admin password managed by Terraform
################################################################################
resource "random_password" "mysql_admin" {
  length           = 16
  override_special = "_#"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

locals {
  mysql_admin_password = random_password.mysql_admin.result
}

output "mysql_admin_password" {
  value     = local.mysql_admin_password
  sensitive = true
}

################################################################################
#  Fetch first availability-domain in the tenancy
################################################################################
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid          # use tenancy OCID
}

locals {
  first_ad = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

################################################################################
#  Auth-Server DB system
################################################################################
module "auth_server_db" {
  source = "${get_original_terragrunt_dir()}/../../../../../terraform/modules/oci/database"

  compartment_id      = var.compartment_id
  subnet_id           = var.subnet_id
  availability_domain = local.first_ad

  db_admin_secret_ocid = ""

  env_name       = "$${var.env_name}-auth"
  admin_username = var.admin_username
  admin_password = local.mysql_admin_password

  shape_name              = var.shape_name
  mysql_version           = var.mysql_version
  enable_heatwave_cluster = var.enable_heatwave_cluster
  heatwave_cluster        = var.heatwave_cluster
  common_tags             = var.common_tags
}

################################################################################
#  Main-API DB system
################################################################################
module "main_api_db" {
  source = "${get_original_terragrunt_dir()}/../../../../../terraform/modules/oci/database"

  compartment_id      = var.compartment_id
  subnet_id           = var.subnet_id
  availability_domain = local.first_ad

  db_admin_secret_ocid = ""

  env_name       = "$${var.env_name}-main"
  admin_username = var.admin_username
  admin_password = local.mysql_admin_password

  shape_name              = var.shape_name
  mysql_version           = var.mysql_version
  enable_heatwave_cluster = var.enable_heatwave_cluster
  heatwave_cluster        = var.heatwave_cluster
  common_tags             = var.common_tags
}
EOF
}

generate "declare_vars" {
  path      = "variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "compartment_id"        { type = string }
variable "tenancy_ocid"          { type = string }
variable "subnet_id"             { type = string }
variable "env_name"              { type = string }
variable "admin_username"        { type = string }
variable "shape_name"            { type = string }
variable "mysql_version"         { type = string }
variable "enable_heatwave_cluster" { type = bool }
variable "heatwave_cluster"      { type = any }
variable "common_tags"           { type = map(string) }
EOF
} 