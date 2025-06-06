variable "compartment_id" {
  description = "The OCID of the compartment where the database will be created."
  type        = string
}

variable "env_name" {
  description = "Environment name for the database system."
  type        = string
}

variable "admin_username" {
  description = "The admin username for the database."
  type        = string
}

variable "availability_domain" {
  description = "The availability domain where the database will be created."
  type        = string
}

variable "subnet_id" {
  description = "The OCID of the subnet where the database will be created."
  type        = string
}

variable "shape_name" {
  description = "The shape of the database system."
  type        = string
}

variable "mysql_version" {
  description = "The MySQL version for the database."
  type        = string  
  nullable = true
  default = null
}

variable "common_tags" {
  description = "Common tags to be applied to the database system."
  type        = map(string) 
}

variable "is_highly_available" {
  description = "Flag to indicate if the database system should be highly available."
  type        = bool
  default     = false
}

variable "admin_password" {
  description = <<DESC
Plain-text admin password for the DB system.  
Takes precedence over `db_admin_secret_ocid`.  
At least one of the two inputs **must** be set.
DESC
  type        = string
  nullable    = true
  default     = null

  validation {
    condition = (
      (var.admin_password != null && trimspace(var.admin_password) != "") ||
      (trimspace(var.db_admin_secret_ocid) != "")
    )
    error_message = "Either admin_password or db_admin_secret_ocid must be provided."
  }
}

variable "db_admin_secret_ocid" {
  description = "OCID of the Vault secret that stores the admin password. Leave empty if admin_password is supplied."
  type        = string
  default     = ""
}

variable "enable_heatwave_cluster" {
  description = "Whether to create a HeatWave cluster for this DB System."
  type        = bool
  default     = false
}

variable "heatwave_cluster" {
  description = "HeatWave cluster configuration. Ignored unless enable_heatwave_cluster = true."
  type = object({
    shape_name = string
    node_count = number
  })
  default = {
    shape_name = "MySQL.HeatWave.VM.Standard.E3.1.32GB"
    node_count = 1
  }
}