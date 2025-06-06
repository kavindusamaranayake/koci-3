resource "oci_load_balancer_load_balancer" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.env_name}-lb"
  shape          = var.shape
  subnet_ids     = var.subnet_ids
  is_private     = var.is_private
  network_security_group_ids = var.nsg_ids
}

resource "oci_load_balancer_backend_set" "this" {
  name             = var.backend_set_name
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    url_path = "/"
    port     = 80
  }
}

resource "oci_load_balancer_backend" "backends" {
  for_each = { for idx, ip in var.backend_ips : "${idx}" => ip }
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.this.name
  ip_address       = each.value
  port             = 80
  weight           = 1
}

resource "oci_load_balancer_listener" "http" {
  count            = var.certificate_id == "" ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.this.name
  protocol         = "HTTP"
  port             = 80
}

resource "oci_load_balancer_listener" "https" {
  count            = var.certificate_id != "" ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.this.name
  protocol         = "HTTPS"
  port             = 443

  ssl_configuration {
    certificate_name        = var.certificate_name
    verify_peer_certificate = false
  }
}

resource "oci_waf_web_app_firewall" "this" {
  count                     = var.waf_policy_id != "" ? 1 : 0
  compartment_id            = var.compartment_id
  backend_type              = "LOAD_BALANCER"
  web_app_firewall_policy_id = var.waf_policy_id
  display_name              = "${var.env_name}-lb-waf"
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
}


## Configure NSGs

