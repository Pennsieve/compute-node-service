// visualization service security group
resource "aws_security_group" "viz" {
  name = "visualization-service-sg"
  vpc_id = aws_default_vpc.default.id

  ingress {
    description = "Allow Port"
    protocol  = "tcp"
    self      = true
    from_port = 80
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "viz-tg" {
  name        = "viz-${var.node_identifier}-tg"
  target_type = "ip"
  port        = 8050
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id

  health_check {
    path = "/health"
  }

}

resource "aws_lb" "viz-lb" {
  name               = "viz-${var.node_identifier}-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = local.subnet_ids_list

  security_groups = [aws_security_group.viz.id,aws_default_security_group.default.id]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "viz-lb-listener" {
  load_balancer_arn = aws_lb.viz-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.viz-tg.arn
  }

  depends_on = [aws_lb_target_group.viz-tg]

}