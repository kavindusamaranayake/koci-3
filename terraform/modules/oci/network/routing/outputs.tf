output "route_table_id" {
  description = "The OCID of the route table."
  value       = oci_core_route_table.this.id
}