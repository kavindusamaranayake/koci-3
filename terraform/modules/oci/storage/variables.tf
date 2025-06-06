variable "compartment_id" {
  description = "The OCID of the compartment to create storage resources in."
  type        = string
}

variable "availability_domain" {
  description = "The Availability Domain to create the block volumes in."
  type        = string # e.g., "Uocm:ca-montreal-1-AD-1"
}

variable "mongodb_volume_size_gb" {
  description = "Size in GB for the MongoDB data volume."
  type        = number
  default     = 50
}

variable "mongodb_volume_name" {
  description = "Display name for the MongoDB data volume."
  type        = string
  default     = "mongodb-data-volume"
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# Add variables for backup policies if needed 

# --- Added Variable ---
variable "kms_key_id" {
  description = "Optional OCID of the OCI KMS key to use for Block Volume encryption."
  type        = string
  default     = null # Encryption disabled by default unless a key OCID is provided
} 