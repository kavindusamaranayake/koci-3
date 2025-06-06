output "id" {
  description = "The OCID of the operator instance."
  value       = oci_core_instance.operator.id
}

output "private_ip" {
  description = "The private IP address of the operator instance."
  value       = oci_core_instance.operator.private_ip
}

output "user" {
  description = "The SSH user for the operator instance."
  value       = var.user
}

// It's generally safer to output the path to a key managed elsewhere
// or expect the consuming module to know the key.
// If you must output the key content for remote-exec, ensure it's marked sensitive.
output "ssh_private_key_for_remote_exec" {
  description = "The SSH private key content for connecting to the operator. Use with caution."
  value       = var.ssh_private_key
  sensitive   = true
}

output "kubeconfig_setup_complete_trigger" {
  description = "ID(s) of the null_resource that creates the kubeconfig. Empty list when generate_kubeconfig=false."
  value       = null_resource.create_kubeconfig[*].id   # returns [] or ["<id>"]
} 