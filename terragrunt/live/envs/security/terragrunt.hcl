###############################################################################
# Includes (root & env-common) – give us providers / region / tags / etc.
###############################################################################

# Keep this include for env-common, as it has expose = true
include "common" {
  path   = find_in_parent_folders("env-common.hcl")
  expose = true
}

###############################################################################
# Dependency: we need VCN id, CIDR, env_name from Network
###############################################################################
dependency "network" {
  config_path = "../network"

  # Add mock_outputs so plan/validate work before network is applied
  mock_outputs = {
    vcn_id         = "ocid1.vcn.oc1..mocknetwork"
    vcn_cidr_block = "10.0.0.0/16" # Mock the VCN CIDR
    # Add mocks for any other network outputs needed by security during planning
    # e.g., subnet IDs/CIDRs if rules depend on them
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"] # Added destroy
}

###############################################################################
# Locals – ONLY pure constants / helpers (no dependency.* here!)
###############################################################################
locals {
  # Environment label we can compute without dependencies
  env_name = "${include.common.locals.name_prefix}-${include.common.locals.env}"

  # -------------------------------------------------------------------------
  # Policy knobs
  # -------------------------------------------------------------------------
  admin_cidr       = "203.0.113.10/32"
  db_ports         = [3306, 33060]
  ssh_port         = 22
  lb_ingress_ports = [80, 443]
  node_port_min    = 30000
  node_port_max    = 32767
  rabbitmq_ports   = [5672, 15672]
  mongodb_ports    = [27017]
  all_private_ips  = "10.0.0.0/8"
  all_ips          = "0.0.0.0/0"

  # --- UPDATED: Point directly to the generic NSG module source ---
  # The NSG module lives under terraform/modules/oci/network/nsg
  nsg_module_source = abspath(
    "${get_terragrunt_dir()}/../../../../../terraform/modules/oci/network/nsg"
  )
  # --- END UPDATED ---

  # --- REMOVED: Rule Sets are moved to the generate block below ---
  # k8s_rules = [ ... ]
  # lb_rules = [ ... ]
  # mysql_rules = [ ... ]
  # bastion_rules = [ ... ]
  # --- END REMOVED ---

  common_tags = include.common.locals.common_tags
}

###############################################################################
# Generate the NSGs Terraform file (nsgs.tf)
###############################################################################
generate "nsgs" {
  path      = "nsgs.tf"
  if_exists = "overwrite_terragrunt"
  contents  = templatefile("${get_terragrunt_dir()}/templates/nsgs.tftpl", {
      # --- Pass constants and dependency outputs ---
      env_name         = local.env_name
      compartment_id   = include.common.locals.compartment_ocid
      vcn_id           = dependency.network.outputs.vcn_id
      vcn_cidr_block   = dependency.network.outputs.vcn_cidr_block # Now accessible here
      admin_cidr       = local.admin_cidr
      db_ports         = local.db_ports
      ssh_port         = local.ssh_port
      lb_ingress_ports = local.lb_ingress_ports
      node_port_min    = local.node_port_min
      node_port_max    = local.node_port_max
      rabbitmq_ports   = local.rabbitmq_ports
      mongodb_ports    = local.mongodb_ports
      # --- FIX: Rename nsg_module_source to module_base_path ---
      module_base_path = local.nsg_module_source # Renamed from nsg_module_source
      # --- END FIX ---
      all_ips          = local.all_ips # Pass this local if needed in the template

      # --- NEW: Define rule sets directly here, accessing dependencies ---
      k8s_rules = [
        # Ingress: Allow NodePort range from anywhere (example - adjust as needed)
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = local.all_ips # Be careful with 0.0.0.0/0
          description = "Allow NodePort traffic from anywhere"
          tcp_options = { destination_port_range = { min = local.node_port_min, max = local.node_port_max } }
        },
        # Ingress: Allow SSH from Admin CIDR (example)
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = local.admin_cidr
          description = "Allow SSH from Admin"
          tcp_options = { destination_port_range = { min = local.ssh_port, max = local.ssh_port } }
        },
        # Egress: Allow all traffic to anywhere
        {
          direction        = "EGRESS"
          protocol         = "all"
          destination_type = "CIDR_BLOCK"
          destination      = local.all_ips
          description      = "Allow all outbound traffic"
        },
        # Add more specific K8s rules as needed
        # Example using dependency (if outputs.tf is configured):
        # {
        #   direction   = "INGRESS"
        #   protocol    = "6" # TCP
        #   source_type = "NETWORK_SECURITY_GROUP"
        #   source      = dependency.security.outputs.bastion_nsg_id # Assumes bastion_nsg_id is in outputs.tf
        #   description = "Allow SSH from Bastion"
        #   tcp_options = { destination_port_range = { min = local.ssh_port, max = local.ssh_port } }
        # },
      ]

      lb_rules = [
        # Ingress: Allow HTTP/HTTPS from anywhere
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = local.all_ips
          description = "Allow HTTP traffic"
          tcp_options = { destination_port_range = { min = 80, max = 80 } }
        },
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = local.all_ips
          description = "Allow HTTPS traffic"
          tcp_options = { destination_port_range = { min = 443, max = 443 } }
        },
        # Egress: Allow traffic to K8s NodePort range (using VCN CIDR)
        {
          direction        = "EGRESS"
          protocol         = "6" # TCP
          destination_type = "CIDR_BLOCK"
          destination      = dependency.network.outputs.vcn_cidr_block # Use VCN CIDR from dependency
          description      = "Allow traffic to K8s Worker NodePorts within VCN"
          tcp_options      = { destination_port_range = { min = local.node_port_min, max = local.node_port_max } }
        },
        # Example using dependency (if outputs.tf is configured):
        # {
        #   direction        = "EGRESS"
        #   protocol         = "6" # TCP
        #   destination_type = "NETWORK_SECURITY_GROUP"
        #   destination      = dependency.security.outputs.k8s_nsg_id # Assumes k8s_nsg_id is in outputs.tf
        #   description      = "Allow traffic to K8s Worker NodePorts"
        #   tcp_options      = { destination_port_range = { min = local.node_port_min, max = local.node_port_max } }
        # },
      ]

      mysql_rules = [
         # Ingress: Allow MySQL ports from VCN CIDR (example)
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = dependency.network.outputs.vcn_cidr_block # Use VCN CIDR from dependency
          description = "Allow MySQL traffic from within VCN"
          tcp_options = { destination_port_range = { min = local.db_ports[0], max = local.db_ports[0] } } # Port 3306
        },
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = dependency.network.outputs.vcn_cidr_block # Use VCN CIDR from dependency
          description = "Allow MySQL X traffic from within VCN"
          tcp_options = { destination_port_range = { min = local.db_ports[1], max = local.db_ports[1] } } # Port 33060
        },
        # Egress: Allow all
        {
          direction        = "EGRESS"
          protocol         = "all"
          destination_type = "CIDR_BLOCK"
          destination      = local.all_ips
          description      = "Allow all outbound traffic"
        },
        # Example using dependency (if outputs.tf is configured):
        # {
        #   direction   = "INGRESS"
        #   protocol    = "6" # TCP
        #   source_type = "NETWORK_SECURITY_GROUP"
        #   source      = dependency.security.outputs.k8s_nsg_id # Assumes k8s_nsg_id is in outputs.tf
        #   description = "Allow MySQL traffic from K8s workers"
        #   tcp_options = { destination_port_range = { min = local.db_ports[0], max = local.db_ports[0] } } # Port 3306
        # },
      ]

      bastion_rules = [
         # Ingress: Allow SSH from Admin CIDR
        {
          direction   = "INGRESS"
          protocol    = "6" # TCP
          source_type = "CIDR_BLOCK"
          source      = local.admin_cidr
          description = "Allow SSH from Admin"
          tcp_options = { destination_port_range = { min = local.ssh_port, max = local.ssh_port } }
        },
         # Egress: Allow SSH to VCN CIDR (example)
        {
          direction        = "EGRESS"
          protocol         = "6" # TCP
          destination_type = "CIDR_BLOCK"
          destination      = dependency.network.outputs.vcn_cidr_block # Use VCN CIDR from dependency
          description      = "Allow SSH to resources within VCN"
          tcp_options      = { destination_port_range = { min = local.ssh_port, max = local.ssh_port } }
        },
         # Egress: Allow all outbound
        {
          direction        = "EGRESS"
          protocol         = "all"
          destination_type = "CIDR_BLOCK"
          destination      = local.all_ips
          description      = "Allow all outbound traffic"
        },
        # Example using dependency (if outputs.tf is configured):
        # {
        #   direction        = "EGRESS"
        #   protocol         = "6" # TCP
        #   destination_type = "NETWORK_SECURITY_GROUP"
        #   destination      = dependency.security.outputs.k8s_nsg_id # Assumes k8s_nsg_id is in outputs.tf
        #   description      = "Allow SSH to K8s workers"
        #   tcp_options      = { destination_port_range = { min = local.ssh_port, max = local.ssh_port } }
        # },
      ]
      # --- END NEW ---
    }
  )
}

###############################################################################
# Generate the Guard detector Terraform file (guard.tf)
###############################################################################
generate "guard" {
  path      = "guard.tf"
  if_exists = "overwrite_terragrunt"
  contents  = templatefile("${get_terragrunt_dir()}/templates/guard.tftpl", {
      env_name         = local.env_name
      compartment_id   = include.common.locals.compartment_ocid
      vcn_id           = dependency.network.outputs.vcn_id
      module_base_path = local.nsg_module_source
    }
  )
}

###############################################################################
# Tell Terragrunt this stack contains Terraform (generated files)
###############################################################################
terraform {
  # Source is the current directory containing the generated .tf files
  source = "../../../../../terraform/modules/oci/security" # Adjust if needed

  # Define outputs for the NSG IDs so other modules (like database) can depend on them
  extra_arguments "output_nsgs" {
    commands = ["output"]
    arguments = [
      "-json"
    ]
  }
}

###############################################################################
# ───────────────────────────  NEW: generated outputs  ────────────────────────
###############################################################################
# Write the Terraform outputs into outputs.tf so Terraform (not Terragrunt)
# can export them and other stacks can consume them through the dependency
# mechanism.
###############################################################################
generate "outputs" {
  path      = "outputs.tf"          # created in the working folder
  if_exists = "overwrite"

  contents = <<-EOT
    # Generated by Terragrunt - DO NOT EDIT MANUALLY

    output "mysql_nsg_id" {
      description = "NSG OCID for the MySQL subnet/instances"
      value       = module.mysql_nsg.nsg_id # Ensure module name matches template
    }

    output "k8s_nsg_id" {
      description = "NSG OCID for Kubernetes worker nodes"
      value       = module.k8s_nsg.nsg_id # Ensure module name matches template
    }

    output "lb_nsg_id" {
      description = "NSG OCID for the public load-balancer"
      value       = module.lb_nsg.nsg_id # Ensure module name matches template
    }

    output "bastion_nsg_id" {
      description = "NSG OCID for bastion hosts"
      value       = module.bastion_nsg.nsg_id # Ensure module name matches template
    }
  EOT
}

