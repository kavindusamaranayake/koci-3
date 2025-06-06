terraform {
  required_version = ">= 1.5.0" # Or your preferred minimum TF version

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.35"
    }
    doppler = {
      source  = "dopplerhq/doppler"
      version = "~> 1.3"
    }
  }
} 