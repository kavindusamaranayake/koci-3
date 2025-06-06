data "cloudinit_config" "bastion" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    # https://cloudinit.readthedocs.io/en/latest/reference/examples.html#run-commands-on-first-boot
    content = <<-EOT
    runcmd:
    - ${format("dnf config-manager --disable ol%v_addons --disable ol%v_appstream", var.bastion_image_os_version, var.bastion_image_os_version) }
    EOT
  }

  part {
    content_type = "text/cloud-config"
    # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#package-update-upgrade-install
    content  = jsonencode({ package_upgrade = var.upgrade })
    filename = "10-packages.yml"
  }

  part {
    content_type = "text/cloud-config"
    # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#timezone
    content  = jsonencode({ timezone = var.timezone })
    filename = "10-timezone.yml"
  }

  part {
    content_type = "text/cloud-config"
    # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#package-update-upgrade-install
    content  = jsonencode({ users = ["default", var.user] })
    filename = "10-user.yml"
  }

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
#cloud-config
packages:
 - curl

runcmd:
 - |
   if [ "${var.tailscale_auth_key}" != "" ]; then
     # Install latest stable
     curl -fsSL https://tailscale.com/install.sh | sh
     # Build the tailscale-up command safely
     TS_CMD="tailscale up --authkey='${var.tailscale_auth_key}' --ssh --accept-routes --accept-dns=false"

     # Advertise subnet routes when provided
     if [ "${join(",", var.vcn_cidrs)}" != "" ]; then
       TS_CMD="$TS_CMD --advertise-routes='${join(",", var.vcn_cidrs)}'"
     fi

     # Optionally act as an exit-node
     %{ if var.tailscale_exit_node }
     TS_CMD="$TS_CMD --advertise-exit-node"
     %{ endif }

     # Execute
     eval "$TS_CMD"
   fi
EOF
  }
}

resource "null_resource" "await_cloudinit" {
  # Only run when we can actually SSH into the VM
  count = (var.await_cloudinit && var.is_public && var.ssh_private_key != "") ? 1 : 0
  connection {
    type        = "ssh"
    host        = oci_core_instance.bastion.public_ip
    user        = "opc"
    private_key = var.ssh_private_key
    timeout     = "10m"
  }

  lifecycle {
    replace_triggered_by = [oci_core_instance.bastion]
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait"]
  }
}