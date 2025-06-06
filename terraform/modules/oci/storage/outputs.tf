output "mongodb_data_volume_id" {
  description = "The OCID of the block volume created for MongoDB data."
  value       = oci_core_volume.mongodb_data.id
}

output "mongodb_data_volume_availability_domain" {
  description = "The Availability Domain of the MongoDB data volume."
  value       = oci_core_volume.mongodb_data.availability_domain
} 