output subnet_id {
  description = "The OCID of the subnet"
  value       = oci_core_subnet.this.id
}

output route_table_id {
  description = "The OCID of the route table"
  value       = var.route_table_id != null ? var.route_table_id : module.rt[0].route_table_id
}