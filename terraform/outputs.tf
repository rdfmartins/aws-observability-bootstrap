# Outputs: Valores de saída para referência rápida após o apply

output "asg_name" {
  description = "Nome do Auto Scaling Group criado"
  value       = aws_autoscaling_group.web_asg.name
}

output "launch_template_id" {
  description = "ID do Launch Template utilizado"
  value       = aws_launch_template.web_lt.id
}

output "vpc_id" {
  description = "ID da VPC Padrão utilizada"
  value       = data.aws_vpc.default.id
}

output "region" {
  description = "Região AWS de deploy"
  value       = var.aws_region
}
