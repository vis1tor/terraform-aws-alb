##########################
# ALB
##########################
variable "alb_info" {
  type = map(object({
    alb_vpc                              = string
    alb_internal                         = string
    alb_ip_address_type                  = string
    alb_subnets                          = list(string)
    alb_sg                               = list(string)
    alb_tags                             = map(string)
    alb_enable_deletion_protection       = string
    alb_enable_cross_zone_load_balancing = string
    alb_preserve_host_header             = string
    alb_client_keep_alive                = string
    alb_enable_xff_client_port           = string
    alb_dns_record_client_routing_policy = string
    alb_access_log_s3_name               = string
    alb_connection_log_s3_name           = string
    alb_listeners = list(object({
      name         = string
      port         = string
      protocol     = string
      target_group = string
    }))
    alb_target_groups = list(object({
      name                              = string
      target_type                       = string
      target                            = list(string)
      ip_address_type                   = string
      port                              = string
      protocol                          = string
      protocol_version                  = string
      deregistration_delay              = string
      load_balancing_cross_zone_enabled = string
      load_balancing_algorithm_type     = string
      health_check = object({
        enabled             = string
        healthy_threshold   = string
        interval            = string
        matcher             = string
        path                = string
        port                = string
        protocol            = string
        timeout             = string
        unhealthy_threshold = string
      })
    }))
  }))
}

variable "alb_name" {
  type = string
}

variable "alb_vpc_id" {
  type = string
}

variable "alb_sg_id" {
  type = list(string)
}

variable "alb_subnets_id" {
  type = list(string)
}

variable "alb_tg_attach_target" {
  type = list(list(object({
    tg_name   = string
    tg_target = string
  })))
}