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

  # Configuração de Health Check para Teste de Caos
  # Type = "EC2": A instância só é substituída se o Hypervisor detectar falha de hardware.
  # Isso permite que a instância sobreviva ao "Disco Cheio" para que o Logrotate atue.
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Instance Refresh: Garante atualização sem downtime (Rolling Update)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0 # Permite recriar mesmo com 1 instância
    }
  }

  # Tagging: Propaga o nome para as instâncias EC2 criadas
  tag {
    key                 = "Name"
    value               = "${var.project_name}-node"
    propagate_at_launch = true
  }
}
