# Data Source: Busca a VPC Padrão da conta
# Evita hardcoding de VPC ID, tornando o código portável para qualquer conta.
data "aws_vpc" "default" {
  default = true
}

# Data Source: Busca as Subnets da VPC Padrão
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Data Source: Recupera as tags padrão definidas no Provider
# Necessário para propagar tags de FinOps para o Auto Scaling Group
data "aws_default_tags" "current" {}