module nsg {
    source         = "../security/nsg"
    name           = "${var.env_name}-lb-nsg"
    env_name       = var.env_name
    compartment_id = var.compartment_id
    vcn_id = var.vcn_id
    rules = []
}