variable "api_p12_file" {}
variable "api_url" {}
variable "healthcheck_name" {}
variable "myns" {}
variable "op_name" {}
variable "pool_port" {}
variable "k8s_svc_name" {}
variable "vsite_name" {}
variable "httplb_name" {}
variable "mydomain" {}

terraform {
  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = "0.7.1"
    }
  }
}

provider "volterra" {
  api_p12_file = var.api_p12_file
  url          = var.api_url
}

// Manage Health Check
resource "volterra_healthcheck" "this" {
  name                = var.healthcheck_name
  namespace           = var.myns
  timeout             = 3
  interval            = 15
  unhealthy_threshold = 1
  healthy_threshold   = 3
  http_health_check {
    use_origin_server_name = true
    path                   = "/"
    use_http2              = false
  }
}

// Manage Origin Pool
resource "volterra_origin_pool" "this" {
  name                   = var.op_name
  namespace              = var.myns
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  port                   = var.pool_port
  no_tls                 = true
  healthcheck {
    name = var.healthcheck_name
  }
  origin_servers {
    k8s_service {
      service_name  = var.service_name
      vk8s_networks = true
      site_locator {
        virtual_site {
          name = var.vsite_name
        }
      }
    }
  }
  depends_on = [volterra_healthcheck.this]
}

// Manage HTTP LoadBalancer
resource "volterra_http_loadbalancer" "this" {
  name                            = var.httplb_name
  namespace                       = var.myns
  domains                         = var.mydomain
  advertise_on_public_default_vip = true
  no_challenge                    = true
  round_robin                     = true
  disable_rate_limit              = true
  no_service_policies             = true
  disable_waf                     = true
  default_route_pools {
    pool {
      name      = var.op_name
      namespace = var.myns
    }
  }
  http {
    dns_volterra_managed = true
  }
  depends_on = [volterra_origin_pool.this]
}
