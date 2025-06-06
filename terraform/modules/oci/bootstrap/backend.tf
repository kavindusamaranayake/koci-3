# Declare that this module uses a backend, which will be configured by Terragrunt.
# For the bootstrap module itself, Terragrunt configures a local backend.
terraform {
  backend "local" {}
} 