resource "aws_lb_target_group" "viz-tg" {
  name        = "viz-${var.node_identifier}-tg"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
}

resource "aws_lb" "viz-lb" {
  name               = "viz-${var.node_identifier}-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = local.subnet_ids_list

  security_groups = [aws_default_security_group.viz.id]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "viz-lb-listener" {
  load_balancer_arn = aws_lb.viz-lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.viz-tg.id
  }
}