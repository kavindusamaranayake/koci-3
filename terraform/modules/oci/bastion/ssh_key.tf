# Generate a temporary ED25519 key-pair when no key was provided
resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "ED25519"
}

# Write the private key to the local workstation so you can use it
resource "local_file" "write_private_key" {
  count          = var.ssh_public_key == "" ? 1 : 0
  content        = tls_private_key.ssh[0].private_key_pem
  filename       = "${path.module}/id_ed25519"
  file_permission = "0600"
}

# Export the public key for use inside the module (and for outputs)
output "public_key_openssh_internal" {
  value = var.ssh_public_key == "" ? tls_private_key.ssh[0].public_key_openssh : var.ssh_public_key
} 