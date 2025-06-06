module "app_nodes_nsg" {
  source         = "../security/nsg"
  name           = "${var.env_name}-oke-app-nsg"
  env_name       = var.env_name
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
}
module "kube_api_nsg" {
  source         = "../security/nsg"
  name           = "${var.env_name}-oke-kubeapi-nsg"
  env_name       = var.env_name
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
}


locals {

  kube_api_rules = concat(
    var.nsg_kubeapi_rules,
    [
    {
            direction = "INGRESS"
            protocol = "6" # TCP
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
            port = 6443
        },
        {
            direction = "INGRESS"
            protocol = "6"
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
            port = 12250
        },
                {
            direction = "INGRESS"
            protocol = "1"
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
        },
        ## Other egress rules as per OCI documentation
        {
            direction = "EGRESS"
            protocol = "6"
            cidr = var.all_services_cidr // All services in Region
            cidr_type = "SERVICE_CIDR_BLOCK"
            port = 443
        },
        {
            direction = "EGRESS"
            protocol = "6"
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
        },
        {
            direction = "EGRESS"
            protocol = "1"
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
        },
        {
            direction = "EGRESS"
            protocol = "6"
            cidr = module.app_nodes_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
            port = 10250
        }
  ]
  )
  work_node_rules = concat(
    [
    {
            direction = "INGRESS"
            protocol = "all" # Allow all traffic to bastion from Cluster API 
            cidr = module.kube_api_nsg.nsg_id
            cidr_type = "NETWORK_SECURITY_GROUP"
        },
        {
            ## Path Disovery as per OCI documentation
            direction = "INGRESS"
            protocol = "1" ## ICMP
            cidr = "0.0.0.0/0" 
            cidr_type = "CIDR_BLOCK"
        }
  ],
    var.nsg_app_rules
  )
}


module "work_node_nsg_rules" {
  source = "../security/rule" 
  for_each = { for idx, rule in local.work_node_rules : idx => rule }

  direction         = each.value.direction
  protocol          = each.value.protocol
  cidr              = each.value.cidr
  cidr_type         = each.value.cidr_type
  port              = try(each.value.port, null)
  port_max          = try(each.value.port_max, null)
  source_port_min   = try(each.value.source_port_min, null)
  source_port_max   = try(each.value.source_port_max, null)
  icmp_type         = try(each.value.icmp_type, null)
  icmp_code         = try(each.value.icmp_code, null)
  stateless         = false
  nsg_id            = module.app_nodes_nsg.nsg_id 
}

module "kube_api_nsg_rules" {
  source = "../security/rule" 
  for_each = { for idx, rule in local.kube_api_rules : idx => rule }

  direction         = each.value.direction
  protocol          = each.value.protocol
  cidr              = each.value.cidr
  cidr_type         = each.value.cidr_type
  port              = try(each.value.port, null)
  port_max          = try(each.value.port_max, null)
  source_port_min   = try(each.value.source_port_min, null)
  source_port_max   = try(each.value.source_port_max, null)
  icmp_type         = try(each.value.icmp_type, null)
  icmp_code         = try(each.value.icmp_code, null)
  stateless         = false
  nsg_id            = module.kube_api_nsg.nsg_id
}