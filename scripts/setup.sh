#!/bin/bash
set -e # Aborta o script em caso de erro

echo "[INFO] Iniciando provisionamento do servidor de Observabilidade..."

# ------------------------------------------------------------------
# 1. Instalação de Pacotes Base (Nginx + CloudWatch Agent)
# ------------------------------------------------------------------
echo "[INFO] Atualizando sistema e instalando dependências..."
apt-get update -y
apt-get install -y nginx wget

# Baixa e instala o Amazon CloudWatch Agent (versão Ubuntu/Debian)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# ------------------------------------------------------------------
# 2. Configuração do Logrotate (A Vacina)
# ------------------------------------------------------------------
echo "[INFO] Configurando Logrotate..."
cat <<'EOF' > /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            systemctl reload nginx > /dev/null 2>&1 || true
        fi
    endscript
}
EOF

# ------------------------------------------------------------------
# 3. Configuração do CloudWatch Agent (O Monitor)
# ------------------------------------------------------------------
echo "[INFO] Configurando CloudWatch Agent..."
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "append_dimensions": {
            "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
            "ImageId": "${aws:ImageId}",
            "InstanceId": "${aws:InstanceId}",
            "InstanceType": "${aws:InstanceType}"
        },
        "metrics_collected": {
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "/"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Inicia o agente carregando a configuração
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

# ------------------------------------------------------------------
# 4. Finalização
# ------------------------------------------------------------------
# Otimização do Journald para persistência
mkdir -p /var/log/journal
sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
systemctl restart systemd-journald

echo "[SUCCESS] Provisionamento concluído: Nginx + Logrotate + CloudWatch Agent."