# Auto Scaling Group: O Garantidor de Disponibilidade
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "${var.project_name}-asg-"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Acoplamento com o Launch Template (A Receita da Instância)
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest" # Sempre usa a versão mais nova do template
  }

  # Health Check do tipo EC2
  health_check_type         = "EC2"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  # Tag Estática: Name
  tag {
    key                 = "Name"
    value               = "${var.project_name}-node"
    propagate_at_launch = true
  }

  # CORREÇÃO FINOPS: Propagação dinâmica das tags do Provider
  # Garante que as tags de custo (Owner, Project) cheguem nas instâncias EC2
  dynamic "tag" {
    for_each = data.aws_default_tags.current.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}