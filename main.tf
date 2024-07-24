locals {
  # Listener 생성
  listener_list = { for k, v in flatten([for k, v in var.alb_info : v.alb_listeners]) : v.name => v }

  # Target Group 생성
  tg_list = { for k, v in flatten([for k, v in var.alb_info : v.alb_target_groups]) : v.name => v }

  # ALB Target Group 정보
  tg_info = flatten([for k, v in flatten([for key, value in var.alb_info : value.alb_target_groups]) : [for kkk, tg_target in v.target : {
    key     = "tga-${regex("tg-(.*)", "${v.name}")[0]}-${kkk}"
    tg_name = v.name
    tg_target = tg_target }]
  ])

  # ALB Target Group Attachment 정보
  tg_target_info = merge([
    for key, value in var.alb_tg_attach_target :
    { for index, item in value :
      "tga-${regex("tg-(.*)", "${item.tg_name}")[0]}-${index}" => item
  }]...)
}

##########################
# ALB
##########################
resource "aws_lb" "this" {
  for_each = var.alb_info

  load_balancer_type               = "application"
  internal                         = each.value.alb_internal
  ip_address_type                  = each.value.alb_ip_address_type
  subnets                          = var.alb_subnets_id
  security_groups                  = var.alb_sg_id
  name                             = each.value.alb_tags.Name
  tags                             = each.value.alb_tags
  enable_deletion_protection       = each.value.alb_enable_deletion_protection
  enable_cross_zone_load_balancing = each.value.alb_enable_cross_zone_load_balancing
  preserve_host_header             = each.value.alb_preserve_host_header
  client_keep_alive                = each.value.alb_client_keep_alive
  enable_xff_client_port           = each.value.alb_enable_xff_client_port
  dns_record_client_routing_policy = each.value.alb_dns_record_client_routing_policy

  dynamic "access_logs" {
    for_each = length(each.value.alb_access_log_s3_name) > 0 ? [each.value.alb_access_log_s3_name] : []

    content {
      bucket  = each.value.alb_access_log_s3_name
      enabled = "true"
    }
  }
  dynamic "connection_logs" {
    for_each = length(each.value.alb_connection_log_s3_name) > 0 ? [each.value.alb_connection_log_s3_name] : []

    content {
      bucket  = each.value.alb_connection_log_s3_name
      enabled = "true"
    }
  }
}

##########################
# ALB Target Listener
##########################
resource "aws_lb_listener" "this" {
  for_each = local.listener_list

  default_action {
    #order            = try(default_action.value.order, null) # alb 옵션으로 추측
    target_group_arn = try(aws_lb_target_group.this[each.value.target_group].arn, null)
    type             = "forward"
  }

  load_balancer_arn = try(aws_lb.this[var.alb_name].arn, null)
  port              = try(each.value.port, null)
  protocol          = try(each.value.protocol, null)

  tags = {
    Name = each.value.name
  }
}

##########################
# ALB Target Group
##########################
resource "aws_lb_target_group" "this" {
  for_each = local.tg_list

  name                              = each.value.name
  target_type                       = try(each.value.target_type, null)
  ip_address_type                   = try(each.value.ip_address_type, null)
  port                              = try(each.value.target_type, null) == "lambda" ? null : try(each.value.port, null)
  protocol                          = try(each.value.target_type, null) == "lambda" ? null : try(each.value.protocol, null)
  protocol_version                  = try(each.value.protocol_version, null)
  deregistration_delay              = try(each.value.deregistration_delay, null)
  load_balancing_cross_zone_enabled = try(each.value.load_balancing_cross_zone_enabled, null)
  load_balancing_algorithm_type     = try(each.value.load_balancing_algorithm_type, null)

  dynamic "health_check" {
    for_each = try([each.value.health_check], [])

    content {
      enabled             = try(health_check.value.enabled, null)
      healthy_threshold   = try(health_check.value.healthy_threshold, null)
      interval            = try(health_check.value.interval, null)
      matcher             = try(health_check.value.matcher, null)
      path                = try(health_check.value.path, null)
      port                = try(health_check.value.port, null)
      protocol            = try(health_check.value.protocol, null)
      timeout             = try(health_check.value.timeout, null)
      unhealthy_threshold = try(health_check.value.unhealthy_threshold, null)
    }
  }

  vpc_id = var.alb_vpc_id

  tags = {
    Name = each.value.name
  }

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = { for k, v in local.tg_info : v.key => v }

  target_group_arn  = aws_lb_target_group.this[each.value.tg_name].arn
  target_id         = local.tg_target_info[each.key].tg_target                                                     # 리소스 모듈의 ID 저장 변수
  availability_zone = try(strcontains(local.tg_target_info[each.key].tg_target, ".") == true ? "all" : null, null) # ip type을 위한
}
