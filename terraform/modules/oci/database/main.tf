data "oci_secrets_secretbundle" "db_admin_password_retrieved" {
  count     = var.db_admin_secret_ocid != "" ? 1 : 0
  secret_id = var.db_admin_secret_ocid
}

locals {
  # returns the first non-null / non-empty value
  admin_password_final = coalesce(
    var.admin_password,
    try(
      base64decode(
        data.oci_secrets_secretbundle.db_admin_password_retrieved[0]
          .secret_bundle_content[0].content
      ),
      null                               # try() swallows the error if the
    )                                    # data source doesn't exist
  )
}

resource "oci_mysql_mysql_db_system" "this" {
    compartment_id = var.compartment_id
    display_name = "${var.env_name}-mysql-db-system"

    admin_username = var.admin_username
    admin_password = local.admin_password_final

    availability_domain = var.availability_domain
    subnet_id = var.subnet_id
    shape_name = var.shape_name
    mysql_version = var.mysql_version
    hostname_label = "${var.env_name}-database"
    freeform_tags = var.common_tags
    is_highly_available = var.is_highly_available

    lifecycle {
    # Prevent Terraform from trying to rotate the password after creation
    ignore_changes = [admin_password]
  }
}

# ──────────────────────────────────────────────────────────────
# Optional HeatWave cluster (separate resource)
# ──────────────────────────────────────────────────────────────
resource "oci_mysql_heat_wave_cluster" "this" {
  count        = var.enable_heatwave_cluster ? 1 : 0

  db_system_id = oci_mysql_mysql_db_system.this.id
  shape_name   = var.heatwave_cluster.shape_name
  cluster_size = var.heatwave_cluster.node_count
}