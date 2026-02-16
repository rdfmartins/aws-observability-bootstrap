# Alarme do CloudWatch para Monitoramento de Disco
# Este alarme observa a métrica customizada enviada pelo CloudWatch Agent.
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project_name}-disk-usage-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "80"
  alarm_description   = "Este alarme dispara quando o uso de disco ultrapassa 80% em qualquer instância do ASG."

  # Dimensões: Devem bater EXATAMENTE com o que o CloudWatch Agent reporta.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
    path                 = "/"
  }

  # Configuração de Notificação (Opcional: Pode ser conectado a um SNS Topic no futuro)
  # alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-disk-alarm"
  }
}

# Alarme de Memória (Opcional, seguindo nossa Baseline de Observabilidade)
resource "aws_cloudwatch_metric_alarm" "mem_high" {
  alarm_name          = "${var.project_name}-memory-usage-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "90"
  alarm_description   = "Este alarme dispara quando o uso de memória ultrapassa 90% no ASG."

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  tags = {
    Name = "${var.project_name}-mem-alarm"
  }
}
