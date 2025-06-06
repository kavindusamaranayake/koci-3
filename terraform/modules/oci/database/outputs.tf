output "db_system_id" {
  description = "The OCID of the MySQL DB System."
  value       = oci_mysql_mysql_db_system.this.id
}

output "db_endpoint" {
  description = "The private IP address of the MySQL DB System endpoint."
  value       = oci_mysql_mysql_db_system.this.ip_address
}

output "db_hostname" {
  description = "The private IP address of the MySQL DB System endpoint."
  value       = oci_mysql_mysql_db_system.this.hostname_label
}
output "db_port" {
  description = "The port number for the MySQL DB System endpoint."
  value       = oci_mysql_mysql_db_system.this.port
}
