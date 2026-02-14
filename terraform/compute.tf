# Busca a AMI mais recente do Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template: A "Receita" da Instância
resource "aws_launch_template" "web_lt" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Associação com o IAM Role (Instance Profile) criado na Fase 2
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # Rede: Security Group criado na Fase 2
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  # Injeção do Script de Setup (Base64 é obrigatório aqui)
  user_data = base64encode(file("${path.module}/../scripts/setup.sh"))

  # Monitoramento detalhado (Opcional, mas recomendado para SRE)
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
