# Data Source: Busca a VPC Padrão da conta
# Evita hardcoding de VPC ID, tornando o código portável para qualquer conta.
data "aws_vpc" "default" {
  default = true
}

# Data Source: Busca as Subnets da VPC Padrão
# O ASG usará essas subnets para distribuir as instâncias (Multi-AZ).
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
