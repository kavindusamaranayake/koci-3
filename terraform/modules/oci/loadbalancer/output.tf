output "load_balancer_id" {
  value = oci_load_balancer_load_balancer.this.id
}

output "load_balancer_ip_addresses" {
  value = oci_load_balancer_load_balancer.this.ip_address_details
}

output "nsg_id" {
  value = module.nsg.nsg_id
}
