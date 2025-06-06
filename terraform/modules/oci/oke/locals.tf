locals {
  arch_map = {
    "VM.Standard.A1" = "arm"
    # default → amd
  }

  # Decide which image OCID to use for the *bootstrap* node-pool.
  # If the default shape is ARM we pick the ARM image; otherwise the AMD/x86 one.
  default_node_pool_image_id = contains(
    ["a1", "aarch64", "arm"],
    lower(var.default_node_pool_shape)
  ) ? var.default_node_pool_image_id_arm : var.default_node_pool_image_id_amd

  # Helper to decide which image ID to use for *other* node-pools
  node_pool_image_id = contains(
    keys(local.arch_map),
    regex("^([^.]+\\.[^.]+)", var.node_shape)[0]
  ) ? var.default_node_pool_image_id_arm : var.default_node_pool_image_id_amd
} 