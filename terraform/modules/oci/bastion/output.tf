output "generated_private_key_pem" {
  description = "Private key generated when ssh_public_key input is empty."
  value       = var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : ""
  sensitive   = true
} 