###############################################################################
# Core-services orchestrator – bootstrap-only pass
###############################################################################

# This file is only an orchestrator; it has no Terraform configuration itself.
# By setting `skip = true` we tell Terragrunt to *not* attempt to run Terraform
# here while still processing the sub-directories listed in `dependencies`.
skip = true

dependencies {
  paths = [
    "./network",
    "./bastion",
    "./database",
    #"./security"
  ]
}