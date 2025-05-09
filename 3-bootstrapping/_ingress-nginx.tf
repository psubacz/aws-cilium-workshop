################################################################################
# References
################################################################################
# - https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

################################################################################
# Locals
################################################################################
locals {
  nginx_controller_namespace = "ingress-nginx"
  # nginx_ingress_controller_sets = merge(
  #   {
  #     "controller.ingressClass"                                                                                   = "nginx"
  #     "controller.ingressClassResource.name"                                                                      = "nginx"
  #     "controller.ingressClassResource.default"                                                                   = "true"
  #     "controller.fullname"                                                                                       = "ingress-nginx-controller"
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"                    = var.cluster_name
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"                    = "external"
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-connection-idle-timeout" = "300"
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"                  = "internet-facing"
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"         = "ip"
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-target-group-attributes" = "preserve_client_ip.enabled=true"
  #     "controller.extraArgs.enable-ssl-passthrough" = ""
  #     "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-negotiation-policy" =  "ELBSecurityPolicy-TLS13-1-2-2021-06"
  #   },
  #   var.nginx_ingress_controller_sets,
  # )

  # nginx_ingress_controller_allowed_cidr_blocks = concat(
  #   module.maxar_cidr_blocks.public_cidrs,
  #   local.allowed_cidrs,
  # )
}

################################################################################
# Variables
################################################################################

variable "install_ingress_nginx_controller" {
  type        = bool
  default     = true
  description = "Whether or not to install the Nginx ingress controller and its resources."
}

variable "ingress_nginx_controller_chart_version" {
  type        = string
  default     = "4.12.2" # appVersion: 1.12.2
  description = "The version of the Nginx Ingress controller chart to use."
  # "4.7.2"  # appVersion: 1.8.2
  # "4.11.2" # appVersion: 1.11.2
  # "4.12.2" # appVersion: 1.12.2
}

variable "nginx_ingress_controller_limit_allowed_cidr_blocks" {
  type        = bool
  default     = true
  description = "Whether or not to limit the Nginx ingress controller's load balancer CIDR blocks to `local.nginx_controller_allowed_cidr_blocks`."
}

variable "nginx_ingress_controller_sets" {
  type        = map(string)
  default     = {}
  description = "A map of additional values to set on the Nginx ingress controller helm chart."
}

################################################################################
# Helm release
################################################################################

# Ref: https://kubernetes.github.io/ingress-nginx/deploy/

resource "helm_release" "ingress_nginx" {
  count = var.install_ingress_nginx_controller ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_controller_chart_version

  namespace        = local.nginx_controller_namespace
  create_namespace = true

  values = [
    templatefile(
      "values/nginx-ingress-controller.yaml", 
      {
      }
    )
  ]
  
  # dynamic "set" {
  #   for_each = local.nginx_ingress_controller_sets

  #   content {
  #     name  = set.key
  #     value = set.value
  #   }
  # }

  depends_on = [
    helm_release.cilium_cni,
    helm_release.load_balancer_controller
  ]
}