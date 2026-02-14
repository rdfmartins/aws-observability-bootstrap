# Security Group para o Web Server
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Permite acesso HTTP na porta 80"

  # Entrada: Apenas HTTP. SSH (22) bloqueado, pois usaremos SSM.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saída: Irrestrita para baixar pacotes e enviar métricas
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
