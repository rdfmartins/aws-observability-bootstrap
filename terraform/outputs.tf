output "asg_name" {
  description = "Nome do Auto Scaling Group criado"
  value       = aws_autoscaling_group.web_asg.name
}

output "launch_template_name" {
  description = "Nome do Launch Template"
  value       = aws_launch_template.web_lt.name
}

output "region" {
  description = "Região AWS"
  value       = var.aws_region
}

# Output Útil: Comando para listar instâncias ativas no ASG via CLI
output "cli_list_instances" {
  description = "Comando AWS CLI para listar IDs das instâncias ativas"
  value       = "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.web_asg.name} --query 'AutoScalingGroups[].Instances[].InstanceId' --output text"
}

# Output Útil: Link direto para o Console de Alarmes
output "cloudwatch_alarm_url" {
  description = "URL para visualizar o Alarme de Disco no Console AWS"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:alarm/${aws_cloudwatch_metric_alarm.disk_high.alarm_name}"
}