resource "null_resource" "create_kubeconfig" {
  count = var.generate_kubeconfig && var.ssh_private_key != "" ? 1 : 0
  # Run exactly once, after the instance is up and cloud-init completed
  depends_on = [null_resource.await_cloudinit]

  triggers = {
    cluster_name   = var.cluster_name
    compartment_id = var.compartment_id
    region         = var.region
    user           = var.user # Added user to triggers as $HOME depends on it
  }

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = oci_core_instance.operator.private_ip
    user                = var.user # Connect and run commands as this user
    private_key         = var.ssh_private_key
    timeout             = "40m"
    type                = "ssh"
  }

  provisioner "remote-exec" {
    # Script runs as var.user (defined in connection block)
    # OCI_CLI_AUTH=instance_principal should be set by cloud-init's .bashrc for this user
    inline = [<<EOF
set -euo pipefail

echo "Running kubeconfig setup as user: $(whoami) in home: $HOME"

# Ensure user's bin directory (common for script-based OCI CLI install) is in PATH
if [ -d "$HOME/bin" ]; then
  export PATH="$HOME/bin:$PATH"
  echo "Updated PATH: $PATH"
fi

# Verify OCI CLI is available and configured for instance principal
echo "Verifying OCI CLI..."
if ! command -v oci >/dev/null 2>&1; then
  echo "OCI CLI command not found in PATH for user $(whoami)."
  exit 1
fi
echo "OCI CLI found at: $(command -v oci)"
echo "Testing OCI CLI auth (instance principal)..."
if ! oci iam region list --query "data[0].name" --raw-output > /dev/null; then
  echo "OCI CLI instance principal authentication test failed."
  # Attempt to show current auth method for debugging
  oci session validate --local || echo "oci session validate also failed"
  exit 1
fi
echo "OCI CLI auth test successful."

# Verify kubectl is available
echo "Verifying kubectl..."
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl command not found in PATH for user $(whoami)."
  exit 1
fi
echo "kubectl found at: $(command -v kubectl)"

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

if [ -f "$HOME/.kube/config" ]; then
  echo "Kubeconfig already exists at $HOME/.kube/config. Skipping creation."
  exit 0
fi

echo "Attempting to find cluster OCID for cluster name: '${var.cluster_name}' in compartment '${var.compartment_id}'"
# Query for ACTIVE or UPDATING clusters to avoid issues with deleted/failed ones
CLUSTER_ID=$(oci ce cluster list \
               --compartment-id "${var.compartment_id}" \
               --name "${var.cluster_name}" \
               --query 'data[?contains(`ACTIVE UPDATING CREATING`, "lifecycle-state")].id | [0]' --raw-output)

if [ -z "$CLUSTER_ID" ] || [ "$CLUSTER_ID" == "null" ]; then
  echo "Error: Could not find an ACTIVE, UPDATING, or CREATING cluster with name '${var.cluster_name}' in compartment '${var.compartment_id}'."
  echo "Available clusters in compartment (debug):"
  oci ce cluster list --compartment-id "${var.compartment_id}" --all --query 'data[*].{name:name, id:id, state:"lifecycle-state"}' --output table || echo "Failed to list clusters for debugging."
  exit 1
fi
echo "Found cluster OCID: $CLUSTER_ID"

echo "Creating kubeconfig for cluster $CLUSTER_ID using private endpoint..."
oci ce cluster create-kubeconfig \
     --cluster-id "$CLUSTER_ID" \
     --file "$HOME/.kube/config" \
     --region "${var.region}" \
     --token-version 2.0.0 \
     --kube-endpoint PRIVATE_ENDPOINT

# Set correct permissions (user already owns the file)
chmod 600 "$HOME/.kube/config"
echo "Kubeconfig created successfully at $HOME/.kube/config"
EOF
    ]
  }
} 