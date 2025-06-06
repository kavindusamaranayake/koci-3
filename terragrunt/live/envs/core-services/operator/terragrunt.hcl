###############################################################################
# Operator VM – builds a small instance, installs OCI-CLI + kubeconfig
###############################################################################

include "common" {
  # tenancy-wide locals / provider settings
  path   = find_in_parent_folders("env-common.hcl")
  expose = true
}

###############################################################################
# network dependency – we only need the subnet where the VM will live
###############################################################################
dependency "network" {
  config_path = "../network"

  # Mock outputs for planning phase
  mock_outputs = {
    subnet_ids = {
      bastion = "ocid1.subnet.oc1..mock"
    }
    vcn_id = "ocid1.vcn.oc1..mock"
    vcn_cidr_block = "10.2.0.0/16"
    subnet_availability_domains = {
      bastion = "AD-1"
    }
    igw_id = "ocid1.internetgateway.oc1..mock"
    ngw_id = "ocid1.natgateway.oc1..mock"
    sgw_id = "ocid1.servicegateway.oc1..mock"
    nsg_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "output", "apply"]
}

###############################################################################
# Operator Terraform module
###############################################################################
terraform {
  # path to your reusable module
  source = "../../../../../terraform/modules/oci//operator"
}

locals {
  # Attempt to read SSH public key, default to a specific marker if not found
  _raw_ssh_public_key = try(
    file("${get_env("HOME")}/.ssh/id_rsa.pub"),
    get_env("OPERATOR_SSH_PUBLIC_KEY", "__DEFAULT_KEY_NOT_FOUND__")
  )
  # Set to null if marker is present (meaning no key was found), otherwise use the key
  _final_ssh_public_key = local._raw_ssh_public_key == "__DEFAULT_KEY_NOT_FOUND__" ? null : local._raw_ssh_public_key
}

inputs = {
  # ─── core placement ────────────────────────────────────────────────────
  # If compartment_ocid is a map use the env-specific key;
  # otherwise fall back to the plain string value.
  compartment_id     = try(
                         include.common.locals.compartment_ocid["core-services"],
                         include.common.locals.compartment_ocid
                       )

  # Use the bastion subnet from the network module
  subnet_id          = try(dependency.network.outputs.subnet_ids["bastion"], "ocid1.subnet.oc1..mock_direct_fallback_operator")
  availability_domain = null

  # full shape map expected by the module
  shape = {
    shape            = "VM.Standard.E4.Flex"
    ocpus            = 1
    memory           = 8            # *** use "memory", not memory_in_gbs ***
    boot_volume_size = 50
  }

  # ─── access & users ────────────────────────────────────────────────────
  user               = "opc"
  # first try to read the default pub-key; if it is missing,
  # fall back to the OPERATOR_SSH_PUBLIC_KEY env-var (or "")
  ssh_public_key     = local._final_ssh_public_key
  ssh_private_key    = get_env("BASTION_SSH_KEY", "")   # same key you use from Terragrunt
                                                         # mark BASTION_SSH_KEY in your env

  # ─── required core identifiers ────────────────────────────────────────
  state_id        = "core-services"
  region          = try(include.common.locals.region, get_env("OCI_REGION", "ca-toronto-1"))
  cluster_name    = "core-services"                 # arbitrary, but required

  # ─── network / DNS / tags ----------------------------------------------------
  # When you have no NSGs, use null so the field is not sent to OCI.
  nsg_ids                 = null
  assign_dns              = false
  tag_namespace           = "koci"
  defined_tags            = {}
  freeform_tags           = include.common.locals.common_tags
  use_defined_tags        = false
  pv_transit_encryption   = false
  # Optional – set to null so Terraform does not send the field
  volume_kms_key_id       = null

  # ─── image & OS -------------------------------------------------------------
  image_id                = "ocid1.image.oc1.ca-toronto-1.aaaaaaaanboz7kt2nnzhoaw7gcodu5dp7255mv2xjenp7y5bazjpfehh4c7q"
  operator_image_os_version = "8"

  # ─── kube-related values (bare minimum) -------------------------------------
  kubeconfig           = ""
  kubernetes_version   = "1.29.1"

  # ─── bastion placeholders (none in this setup) ------------------------------
  bastion_host         = ""
  bastion_user         = ""

  # ─── cloud-init & misc -------------------------------------------------------
  await_cloudinit      = false
  cloud_init           = []           # list(map(string)) as required
  timezone             = "UTC"
  upgrade              = true

  # ─── tool install toggles ----------------------------------------------------
  install_cilium            = false
  install_helm              = false
  install_helm_from_repo    = false
  install_istioctl          = false
  install_k9s               = false
  install_kubectx           = false
  install_stern             = false

  # keep operator module from trying to build OCI CLI from source repo
  install_oci_cli_from_repo = false

  # set to true once your OKE cluster is ready and you want the VM to
  # pull the kubeconfig; leave false to skip the remote-exec step
  generate_kubeconfig = false
} 