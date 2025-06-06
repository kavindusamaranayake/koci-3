variable "compartment_id" {
  type        = string
  description = "OCID of the compartment"
}

variable "env_name" {
  type        = string
  description = "Environment name like dev, staging, prod"
}

variable "vcn_id" {
  type        = string
  description = "VCN ID from network module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}


variable "vault_display_name" {
  description = "Display name for the OCI Vault."
  type        = string
  default     = "koci-shared-vault"
}

variable "vault_type" {
  description = "Type of Vault (DEFAULT or VIRTUAL_PRIVATE)."
  type        = string
  default     = "DEFAULT" # Uses public endpoints accessible over the internet
}

variable "tfstate_key_display_name" {
  description = "Display name for the Master Key used for encrypting Terraform state."
  type        = string
  default     = "koci-tfstate-key"
}

variable "data_key_display_name" {
  description = "Display name for the Master Key used for encrypting data (Block Volumes, DBs, etc.)."
  type        = string
  default     = "koci-data-key"
}

variable "db_admin_secret_name" {
  description = "Name of the secret in the Vault to store the DB admin password."
  type        = string
  default     = "koci_DB_ADMIN_PASSWORD" # Use names suitable for secrets
}

variable "tags" {
  description = "Common tags to apply to security resources."
  type        = map(string)
  default     = {}
} 

variable "vcn_cidr" {
  description = "The primary CIDR block for the VCN."
  type        = string
  # Example: "10.0.0.0/16"
}

variable "service_cidr_destination" {
  type        = string
  description = "Destination value to use when destination_type == SERVICE_CIDR_BLOCK"
  default     = "all-ca-toronto-1-services-in-oracle-services-network"
}