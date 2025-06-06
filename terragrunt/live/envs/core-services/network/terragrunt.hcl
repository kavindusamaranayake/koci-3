# Keep this include for env-common, as it has expose = true
include "common" {
  path   = find_in_parent_folders("env-common.hcl")
  expose = true
}

terraform {
  source = "../../../../../terraform/modules/oci/network"
}

# ─── locals ──────────────────────────────────────────────────────────────
locals {
  # base slug → "koci-dev"
  env_name_base = "${include.common.locals.name_prefix}-${include.common.locals.env}"
  env_name      = local.env_name_base
  region        = include.common.locals.region

  # derive DNS-safe label from "<base>-vcn"
  vcn_dns_label = substr(replace(lower("${local.env_name_base}-vcn"), "-", ""), 0, 15)

  #########################################################################
  # Availability Domains – specify *how many* we need, then derive labels
  #########################################################################
  ad_count            = 1
  availability_domains = [
    for i in range(local.ad_count) : "AD-${i + 1}"
  ]

  # ─── VCN settings ───────────────────────────────────────────────────────
  vcn_cidr = "10.2.0.0/16"

#  raw_subnets = {
#    # ── single-AD tiers ──────────────────────────────────────────
#    bastion = { newbits = 8,  dns_label = "bastion", gateway_type = "igw",  ha = false } # /24  → 256   (251 usable)
#    data    = { newbits = 8,  dns_label = "data",    gateway_type = "sgw",  ha = false } # /24  → 256   (251 usable)
#
#    # ── multi-AD tiers ───────────────────────────────────────────
#    cp      = { newbits = 10, dns_label = "cp",      gateway_type = "ngw",  ha = true  } # /26 × ADs → 64   (59 usable)
#    int_lb  = { newbits = 11, dns_label = "ilb",     gateway_type = "ngw",  ha = true  } # /27 × ADs → 32   (27 usable)
#    pub_lb  = { newbits = 11, dns_label = "plb",     gateway_type = "igw",  ha = true  } # /27 × ADs → 32   (27 usable)
#    workers = { newbits = 7,  dns_label = "workers", gateway_type = "sgw",  ha = true  } # /23 × ADs → 512  (507 usable)
#    pods    = { newbits = 4,  dns_label = "pods",    gateway_type = "sgw",  ha = true  } # /20 × ADs → 4096 (4091 usable)
#  }


  #########################################################################
  # Subnet sizing  –  OCI single-AD best practice
  #########################################################################
  #raw_subnets = {
  #  bastion = { newbits = 8,  netnum = 64,  dns_label = "bastion", gateway_type = "igw",  ha = false } # 10.2.64.0/24
  #  data    = { newbits = 8,  netnum = 65,  dns_label = "data",    gateway_type = "sgw",  ha = false } # 10.2.65.0/24
  #  cp      = { newbits = 10, netnum = 264, dns_label = "cp",      gateway_type = "ngw",  ha = false } # 10.2.66.0/26
  #  int_lb  = { newbits = 11, netnum = 530, dns_label = "ilb",     gateway_type = "ngw",  ha = false } # 10.2.66.64/27
  #  pub_lb  = { newbits = 11, netnum = 531, dns_label = "plb",     gateway_type = "igw",  ha = false } # 10.2.66.96/27
  #  workers = { newbits = 7,  netnum = 34,  dns_label = "workers", gateway_type = "sgw",  ha = false } # 10.2.68.0/23
  #  pods    = { newbits = 4,  netnum = 8,   dns_label = "pods",    gateway_type = "sgw",  ha = false } # 10.2.128.0/20
  #}

  raw_subnets = {
    bastion = { newbits = 11, netnum = 512, dns_label = "bastion", gateway_type = "igw",  ha = false } # 10.2.64.0/27
    data    = { newbits = 8,  netnum = 65,  dns_label = "data",    gateway_type = "sgw",  ha = false } # 10.2.65.0/24
    cp      = { newbits = 10, netnum = 264, dns_label = "cp",      gateway_type = "ngw",  ha = false } # 10.2.66.0/26
    int_lb  = { newbits = 10, netnum = 265, dns_label = "ilb",     gateway_type = "ngw",  ha = false } # 10.2.66.64/26
    pub_lb  = { newbits = 10, netnum = 266, dns_label = "plb",     gateway_type = "igw",  ha = false } # 10.2.66.128/26
    workers = { newbits = 7,  netnum = 34,  dns_label = "workers", gateway_type = "sgw",  ha = false } # 10.2.68.0/23
    pods    = { newbits = 4,  netnum = 8,   dns_label = "pods",    gateway_type = "sgw",  ha = false } # 10.2.128.0/20
  }


  #########################################################################
  # Stable, collision-free subnet enumeration
  #########################################################################
  base_order = [
    "bastion", "data", "cp", "int_lb", "pub_lb", "workers", "pods"
  ]

  expanded_subnets = [
    for name in local.base_order : merge(
      local.raw_subnets[name],
      {
        name      = name
        base_name = name
        ad        = null
        # use explicit netnum if present; otherwise fall back to index()
        netnum    = lookup(local.raw_subnets[name], "netnum", index(local.base_order, name))
      }
    )
  ]

  subnets = {
    for s in local.expanded_subnets :
    s.name => merge(
      s,
      { cidr = cidrsubnet(local.vcn_cidr, s.newbits, s.netnum) }
    )
  }

  sorted_subnet_names = sort([for s in local.expanded_subnets : s.name])
  subnets_list        = [
    for n in local.sorted_subnet_names :
    merge(local.subnets[n], { name = n })
  ]


  trusted_nodeport_sources = flatten([
    for name in ["cp", "int_lb", "bastion"] :
    contains(keys(local.subnets), name) ? [local.subnets[name].cidr] : []
  ])

  # ─── CNI choice & associated VXLAN ports ────────────────────────────────
  # • default is Calico; override in env-common.kocil with:  cni_type = "flannel"
  cni_type = try(include.common.locals.cni_type, "calico")

  cni_udp_rules = (
    local.cni_type == "flannel" ? [
      # Flannel VXLAN (UDP 4789)
      {
        direction   = "INGRESS"
        protocol    = "17"
        description = "Flannel VXLAN 4789"
        source      = local.vcn_cidr
        source_type = "CIDR_BLOCK"
        udp_options = { destination_port_range = { min = 4789, max = 4789 } }
      },
      # Legacy Flannel UDP 6081
      {
        direction   = "INGRESS"
        protocol    = "17"
        description = "Flannel UDP 6081"
        source      = local.vcn_cidr
        source_type = "CIDR_BLOCK"
        udp_options = { destination_port_range = { min = 6081, max = 6081 } }
      }
    ] : [] # For "calico", "oci_vcn_native", or any other CNI, no specific VXLAN rules are added here.
  )

  # -----------------------------------------------------------
  # Extra "singleton" NSGs that are *not* tied to a subnet
  # - removed the unused `operator`
  # -----------------------------------------------------------
  extra_nsg_keys = ["fss", "pods", "workers"]

  # NOTE: the final `nsgs` map is built later in this locals block
  #       after the detailed rule-sets are defined.

  # toggles / ACL helpers
  bastion_allowed_cidrs        = ["0.0.0.0/0"]
  allow_worker_ssh_access      = true
  allow_bastion_cluster_access = true
  allow_node_port_access       = true
  allow_worker_internet_access = true
  allow_pod_internet_access    = true

  # LB listeners
  allow_rules_public_lb = {
    HTTP  = { protocol = "6", tcp_options = { destination_port_range = { min = 80,  max = 80 } }, source = "0.0.0.0/0", source_type = "CIDR_BLOCK" }
    HTTPS = { protocol = "6", tcp_options = { destination_port_range = { min = 443, max = 443 } }, source = "0.0.0.0/0", source_type = "CIDR_BLOCK" }
  }
  allow_rules_internal_lb = {
    HTTP  = { protocol = "6", tcp_options = { destination_port_range = { min = 80,  max = 80 } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
    HTTPS = { protocol = "6", tcp_options = { destination_port_range = { min = 443, max = 443 } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
  }

  allow_rules_workers = {
    RabbitMQ_AMQP  = { protocol = "6", tcp_options = { destination_port_range = { min = 5672,  max = 5672  } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
    RabbitMQ_Mgmt  = { protocol = "6", tcp_options = { destination_port_range = { min = 15672, max = 15672 } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
    MongoDB        = { protocol = "6", tcp_options = { destination_port_range = { min = 27017, max = 27017 } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
    MySQL_HeatWave = { protocol = "6", tcp_options = { destination_port_range = { min = 3306,  max = 3306  } }, source = local.vcn_cidr, source_type = "CIDR_BLOCK" }
  }

  load_balancers          = "both"
  preferred_load_balancer = "public"

  common_tags = {
    ManagedBy   = "koci-Terraform"
    Environment = include.common.locals.env
    Project     = include.common.locals.doppler_project # Get project from root
  }

  
  admin_cidr       = "203.0.113.10/32" # Example: Replace with actual admin IP/CIDR
  common_inputs = try(include.common.locals.common_inputs, {})

  # (subnets_list is now defined once – see the "Stable, collision-free
  # subnet enumeration" section above)

  # ── NSG RULE SETS ────────────────────────────────────────────────────────

  nsg_rules_cp = [
  # Kubernetes API access from worker nodes / bastion
  {
    direction        = "INGRESS"
    protocol         = "6"
    description      = "K8s API"
    source           = local.vcn_cidr
    source_type      = "CIDR_BLOCK"
    tcp_options = {
      destination_port_range = { min = 6443, max = 6443 }
    }
  },

  # Kubelet egress to nodes (10250)
  {
    direction        = "EGRESS"
    protocol         = "6"
    description      = "Kubelet"
    destination      = local.vcn_cidr
    destination_type = "CIDR_BLOCK"
    tcp_options = {
      destination_port_range = { min = 10250, max = 10250 }
    }
  },

  # NodePort support (TCP/UDP)
  {
    direction        = "EGRESS"
    protocol         = "6"
    description      = "NodePort TCP egress to workers"
    destination      = local.vcn_cidr
    destination_type = "CIDR_BLOCK"
    tcp_options = {
      destination_port_range = { min = 30000, max = 32767 }
    }
  },
  {
    direction        = "EGRESS"
    protocol         = "17"
    description      = "NodePort UDP egress to workers"
    destination      = local.vcn_cidr
    destination_type = "CIDR_BLOCK"
    udp_options = {
      destination_port_range = { min = 30000, max = 32767 }
    }
  },

  # ICMP (optional but useful for MTU and diagnostics)
  {
    direction        = "EGRESS"
    protocol         = "1"
    description      = "ICMP to workers"
    destination      = local.vcn_cidr
    destination_type = "CIDR_BLOCK"
  },

  # DNS resolution (TCP and UDP to OCI DNS)
  {
    direction        = "EGRESS"
    protocol         = "6"
    description      = "DNS TCP"
    destination      = "169.254.169.254/32"
    destination_type = "CIDR_BLOCK"
    tcp_options = {
      destination_port_range = { min = 53, max = 53 }
    }
  },
  {
    direction        = "EGRESS"
    protocol         = "17"
    description      = "DNS UDP"
    destination      = "169.254.169.254/32"
    destination_type = "CIDR_BLOCK"
    udp_options = {
      destination_port_range = { min = 53, max = 53 }
    }
  }
]

#    nsg_rules_cp = [
#      { direction = "INGRESS", protocol = "6",  description = "K8s API",
#        source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#        tcp_options = { destination_port_range = { min = 6443,  max = 6443 } } },
#
#      { direction = "EGRESS",  protocol = "6",  description = "Kubelet",
#        destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
#        tcp_options = { destination_port_range = { min = 12250, max = 12250 } } },
#
#      # ── NEW : NodePort traffic (best-practice) ────────────────────────────
#      { direction = "EGRESS",  protocol = "6",  description = "NodePort TCP egress to workers",
#        destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
#        tcp_options = { destination_port_range = { min = 30000, max = 32767 } } },
#
#      { direction = "EGRESS",  protocol = "17", description = "NodePort UDP egress to workers",
#        destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
#        udp_options = { destination_port_range = { min = 30000, max = 32767 } } },
#    ]

  nsg_rules_workers = concat(
    flatten([
      for cidr in local.trusted_nodeport_sources : [
        {
          direction   = "INGRESS"
          protocol    = "6"
          description = "NodePort TCP from trusted"
          source      = cidr
          source_type = "CIDR_BLOCK"
          tcp_options = {
            destination_port_range = { min = 30000, max = 32767 }
          }
        },
        {
          direction   = "INGRESS"
          protocol    = "17"
          description = "NodePort UDP from trusted"
          source      = cidr
          source_type = "CIDR_BLOCK"
          udp_options = {
            destination_port_range = { min = 30000, max = 32767 }
          }
        }
      ]
    ]),
    local.cni_udp_rules,
    [
      # ICMP
      {
        direction   = "INGRESS"
        protocol    = "1"
        description = "ICMP intra-VCN"
        source      = local.vcn_cidr
        source_type = "CIDR_BLOCK"
        icmp_options = {
          type = 3
          code = 4
        }
      },

      # Intra-VCN
      {
        direction   = "INGRESS"
        protocol    = "6"
        description = "TCP intra-VCN"
        source      = local.vcn_cidr
        source_type = "CIDR_BLOCK"
      },
      {
        direction   = "INGRESS"
        protocol    = "17"
        description = "UDP intra-VCN"
        source      = local.vcn_cidr
        source_type = "CIDR_BLOCK"
      },

      # Outbound HTTPS + DNS
      {
        direction   = "EGRESS"
        protocol    = "6"
        description = "HTTPS outbound 443"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
        tcp_options = {
          destination_port_range = { min = 443, max = 443 }
        }
      },
      {
        direction   = "EGRESS"
        protocol    = "6"
        description = "DNS TCP"
        destination = "169.254.169.254/32"
        destination_type = "CIDR_BLOCK"
        tcp_options = {
          destination_port_range = { min = 53, max = 53 }
        }
      },
      {
        direction   = "EGRESS"
        protocol    = "17"
        description = "DNS UDP"
        destination = "169.254.169.254/32"
        destination_type = "CIDR_BLOCK"
        udp_options = {
          destination_port_range = { min = 53, max = 53 }
        }
      },
      # --- NEW DNS rules for 169.254.169.253 -----------------------
      {
        direction   = "EGRESS"
        protocol    = "6"
        description = "DNS TCP (.253)"
        destination = "169.254.169.253/32"
        destination_type = "CIDR_BLOCK"
        tcp_options = {
          destination_port_range = { min = 53, max = 53 }
        }
      },
      {
        direction   = "EGRESS"
        protocol    = "17"
        description = "DNS UDP (.253)"
        destination = "169.254.169.253/32"
        destination_type = "CIDR_BLOCK"
        udp_options = {
          destination_port_range = { min = 53, max = 53 }
        }
      }
    ],
    [
      {
        direction        = "EGRESS"
        protocol         = "6"
        description      = "Worker → API server 6443"
        destination      = local.vcn_cidr
        destination_type = "CIDR_BLOCK"
        tcp_options = {
          destination_port_range = { min = 6443, max = 6443 }
        }
      }
    ]
  )


#  nsg_rules_workers = [
#    { direction = "INGRESS", protocol = "6",  description = "NodePort TCP", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#      tcp_options = { destination_port_range = { min = 30000, max = 32767 } } },
#    { direction = "INGRESS", protocol = "17", description = "NodePort UDP", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#      udp_options = { destination_port_range = { min = 30000, max = 32767 } } },
#    { direction = "INGRESS", protocol = "17", description = "VXLAN / Flannel 4789", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#      udp_options = { destination_port_range = { min = 4789, max = 4789 } } },
#    { direction = "INGRESS", protocol = "17", description = "Flannel 6081",  source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#      udp_options = { destination_port_range = { min = 6081, max = 6081 } } },
#    { direction = "INGRESS", protocol = "1",  description = "ICMP intra-VCN", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
#      icmp_options = { type = 3, code = 4 } },
#    { direction = "INGRESS", protocol = "6",  description = "TCP intra-VCN", source = local.vcn_cidr, source_type = "CIDR_BLOCK" },
#    { direction = "INGRESS", protocol = "17", description = "UDP intra-VCN", source = local.vcn_cidr, source_type = "CIDR_BLOCK" },
#    # --- egress required for registry pulls & DNS ---------------------------
#    { direction = "EGRESS", protocol = "6",  description = "HTTPS outbound 443",
#      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
#      tcp_options = { destination_port_range = { min = 443, max = 443 } } },
#    { direction = "EGRESS", protocol = "6",  description = "DNS TCP 53",
#      destination = "169.254.169.254/32", destination_type = "CIDR_BLOCK",
#      tcp_options = { destination_port_range = { min = 53,  max = 53 } } },
#    { direction = "EGRESS", protocol = "17", description = "DNS UDP 53",
#      destination = "169.254.169.254/32", destination_type = "CIDR_BLOCK",
#      udp_options = { destination_port_range = { min = 53,  max = 53 } } },
#  ]

  # `pods` and `workers` share the exact same rule-set.  Point pods
  # directly at workers to avoid maintaining two identical lists.
  nsg_rules_pods = local.nsg_rules_workers

  nsg_rules_int_lb  = [
    { direction = "INGRESS", protocol = "6", description = "HTTP from VCN",  source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 80,  max = 80 } } },
    { direction = "INGRESS", protocol = "6", description = "HTTPS from VCN", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 443, max = 443 } } },
    { direction = "EGRESS",  protocol = "all", description = "To back-end pools", destination = local.vcn_cidr, destination_type = "CIDR_BLOCK" },
  ]

  nsg_rules_pub_lb  = [
    { direction = "INGRESS", protocol = "6", description = "HTTP",  source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 80,  max = 80 } } },
    { direction = "INGRESS", protocol = "6", description = "HTTPS", source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 443, max = 443 } } },
    { direction = "EGRESS",  protocol = "all", description = "LB egress", destination = local.vcn_cidr, destination_type = "CIDR_BLOCK" },
  ]

  nsg_rules_data = [
    { direction = "INGRESS", protocol = "6", description = "MySQL 3306", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 3306, max = 3306 } } },
    # MySQL X-protocol
    { direction = "INGRESS", protocol = "6", description = "MySQL 33060-61",
      source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 33060, max = 33061 } } },
    # MySQL InnoDB-Cluster
    { direction = "INGRESS", protocol = "6", description = "MySQL InnoDB 4567-68",
      source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 4567, max = 4568 } } },
    { direction = "INGRESS", protocol = "6", description = "MySQL InnoDB 4444",
      source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 4444, max = 4444 } } },
    # MongoDB intra-VCN
    { direction = "INGRESS", protocol = "6", description = "MongoDB 27017 ingress",
      source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 27017, max = 27017 } } },
    { direction = "EGRESS",  protocol = "6", description = "MySQL 3306 egress",
      destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 3306,  max = 3306  } } },
    { direction = "EGRESS",  protocol = "6", description = "MySQL 33060-61 egress",
      destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 33060, max = 33061 } } },
    { direction = "EGRESS",  protocol = "6", description = "MySQL InnoDB 4567-68 egress",
      destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 4567,  max = 4568  } } },
    { direction = "EGRESS",  protocol = "6", description = "MySQL InnoDB 4444 egress",
      destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 4444,  max = 4444  } } },
    { direction = "EGRESS",  protocol = "6", description = "MongoDB 27017 egress",
      destination = local.vcn_cidr, destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 27017, max = 27017 } } },
  ]

  nsg_rules_bastion = [
    { direction = "EGRESS", protocol = "17", description = "Tailscale 41641",
      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
      udp_options = { destination_port_range = { min = 41641, max = 41641 } } },

    { direction = "EGRESS", protocol = "6",  description = "HTTPS 443",
      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 443, max = 443 } } },

    { direction = "EGRESS", protocol = "17", description = "UDP 443",
      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
      udp_options = { destination_port_range = { min = 443, max = 443 } } },

    # Removed open HTTP/80 egress.  Bastion still has HTTPS/443 and
    # the required Tailscale / STUN ports.

    { direction = "EGRESS", protocol = "1",  description = "ICMP path discovery",
      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
      icmp_options = { type = 3, code = 4 } },

    # optional inbound diagnostics
    { direction = "INGRESS", protocol = "17", description = "VCN UDP 41641", source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      udp_options = { destination_port_range = { min = 41641, max = 41641 } } },
    { direction = "INGRESS", protocol = "17", description = "VCN UDP 443",   source = local.vcn_cidr, source_type = "CIDR_BLOCK",
      udp_options = { destination_port_range = { min = 443, max = 443 } } },
    { direction = "INGRESS", protocol = "6",  description = "SSH from admin", source = local.admin_cidr, source_type = "CIDR_BLOCK",
      tcp_options = { destination_port_range = { min = 22, max = 22 } } },
    # STUN for Tailscale
    { direction = "EGRESS", protocol = "17", description = "STUN 3478/UDP",
      destination = "0.0.0.0/0", destination_type = "CIDR_BLOCK",
      udp_options = { destination_port_range = { min = 3478, max = 3478 } } },
  ]

  # ── COMPOSE FINAL NSG MAP (every value has a `rules` list) ───────────────

  # 1. Canonical rule-sets keyed by *base* subnet name
  base_nsg_rule_map = {
    cp      = local.nsg_rules_cp
    workers = local.nsg_rules_workers
    pods    = local.nsg_rules_pods
    int_lb  = local.nsg_rules_int_lb
    pub_lb  = local.nsg_rules_pub_lb
    data    = local.nsg_rules_data
    bastion = local.nsg_rules_bastion
    fss     = local.nsg_rules_fss
  }

  # 2. Final NSG map – every subnet key (expanded or not) gets a value
  nsgs = {
    for key in distinct(concat(keys(local.subnets), local.extra_nsg_keys)) :
    key => {
      # Strip "_ad1", "_ad2", ... to look up the canonical rule-set;
      # fallback to empty list when no policy is defined.
      rules = try(
        local.base_nsg_rule_map[replace(key, "_ad[0-9]+$", "")],
        []
      )
    }
  }

  # --- File-Storage Service --------------------------------------
  nsg_rules_fss = [
    # NFS
    {
      direction      = "INGRESS"
      protocol       = "6"
      description    = "FSS NFS 2049/TCP"
      source         = local.vcn_cidr
      source_type    = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 2049, max = 2049 } }
    },
    # RPCBind 111
    {
      direction    = "INGRESS"
      protocol     = "6"
      description  = "FSS RPC 111/TCP"
      source       = local.vcn_cidr
      source_type  = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 111, max = 111 } }
    },
    {
      direction    = "INGRESS"
      protocol     = "17"
      description  = "FSS RPC 111/UDP"
      source       = local.vcn_cidr
      source_type  = "CIDR_BLOCK"
      udp_options = { destination_port_range = { min = 111, max = 111 } }
    },
    # mountd 635
    {
      direction    = "INGRESS"
      protocol     = "6"
      description  = "FSS mountd 635/TCP"
      source       = local.vcn_cidr
      source_type  = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 635, max = 635 } }
    },
    {
      direction    = "INGRESS"
      protocol     = "17"
      description  = "FSS mountd 635/UDP"
      source       = local.vcn_cidr
      source_type  = "CIDR_BLOCK"
      udp_options = { destination_port_range = { min = 635, max = 635 } }
    },
  ]
}

# ─── override the inherited S3 backend ─────────────────────────────
#remote_state {
#  backend = "local"
#  config = {
#  # Terragrunt will generate   backend "local" { ... }   in the child module
#  config = {
#    path = "${get_terragrunt_dir()}/terraform.tfstate"
#  }
#}

###############################################################################
# Ensure Terraform has a backend "local" block so Terragrunt can override it
###############################################################################
generate "backend_placeholder" {
  path      = "backend.tf"          # will live next to the downloaded module
  if_exists = "skip"                # don't touch if the module ever adds one
  contents  = <<EOF
terraform {
  backend "local" {}
}
EOF
}

###############################################################################
# inputs – everything the terraform/oci/network module expects
###############################################################################
inputs = merge(
  local.common_inputs,
  {
    # ── mandatory ───────────────────────────────────────────────────────────
    compartment_id = try(include.common.locals.compartment_ocid, "")
    tenancy_ocid   = try(include.common.locals.tenancy_ocid,   "")
    env_name       = local.env_name
    vcn_cidr       = local.vcn_cidr
    vcn_dns_label  = local.vcn_dns_label

    # pass the **list**, not the original map
    subnets        = local.subnets_list

    # NSGs + tags
    network_security_groups = local.nsgs
    common_tags             = local.common_tags

    # ── feature toggles & rule maps ─────────────────────────────────────────
    bastion_allowed_cidrs        = local.bastion_allowed_cidrs
    allow_worker_ssh_access      = local.allow_worker_ssh_access
    allow_bastion_cluster_access = local.allow_bastion_cluster_access
    allow_node_port_access       = local.allow_node_port_access
    allow_worker_internet_access = local.allow_worker_internet_access
    allow_pod_internet_access    = local.allow_pod_internet_access

    load_balancers          = local.load_balancers
    preferred_load_balancer = local.preferred_load_balancer

    allow_rules_public_lb   = local.allow_rules_public_lb
    allow_rules_internal_lb = local.allow_rules_internal_lb
    allow_rules_workers     = local.allow_rules_workers

    # Make sure the module gets its required region variable
    region = local.region
  }
)
