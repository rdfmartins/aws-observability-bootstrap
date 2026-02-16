#!/bin/bash
set -e # Aborta o script em caso de erro

echo "[INFO] Iniciando provisionamento do servidor de Observabilidade..."

# ------------------------------------------------------------------
# 1. Instalação de Pacotes Base (Nginx + CloudWatch Agent)
# ------------------------------------------------------------------
echo "[INFO] Atualizando sistema e instalando dependências..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx wget

# Garante que o Nginx inicie no boot e rode agora (Pontos 4 e 5 da sua lista)
echo "[INFO] Habilitando serviço Nginx..."
systemctl enable nginx
systemctl start nginx

# Baixa e instala o Amazon CloudWatch Agent
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

# Cria um atalho para facilitar o teste de remediação manual (Ponto 2)
echo '#!/bin/bash' > /usr/local/bin/remediate
echo 'logrotate -f -v /etc/logrotate.d/nginx' >> /usr/local/bin/remediate
chmod +x /usr/local/bin/remediate
echo "[INFO] Atalho 'remediate' criado em /usr/local/bin/."

# ------------------------------------------------------------------
# 3. Configuração do CloudWatch Agent (O Monitor)
# ------------------------------------------------------------------
echo "[INFO] Configurando CloudWatch Agent (Versão Completa)..."
# Incorporando as dimensões extras que você gostou (Ponto 1)
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}",
            "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
            "ImageId": "${aws:ImageId}",
            "InstanceType": "${aws:InstanceType}"
        },
        "metrics_collected": {
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["/"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Inicia o agente
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

# Valida se o agente iniciou corretamente (Ponto 4)
sleep 5
echo "[INFO] Verificando status do CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

# ------------------------------------------------------------------
# 4. Ferramenta de Caos (Chaos Engineering)
# ------------------------------------------------------------------
echo "[INFO] Instalando script de Caos em /usr/local/bin/chaos-maker..."
cat <<'EOF' > /usr/local/bin/chaos-maker
#!/bin/bash
LOG_FILE="/var/log/nginx/access.log"
AVAILABLE_SPACE=$(df / --output=avail | tail -1)
BUFFER_KB=500000
FILL_AMOUNT_KB=$((AVAILABLE_SPACE - BUFFER_KB))

if [ $FILL_AMOUNT_KB -le 0 ]; then
    echo "[CHAOS] Disco já está cheio."
    exit 1
fi

echo "[CHAOS] Preenchendo $((FILL_AMOUNT_KB / 1024)) MB em $LOG_FILE..."
fallocate -l ${FILL_AMOUNT_KB}K $LOG_FILE || head -c ${FILL_AMOUNT_KB}K < /dev/zero >> $LOG_FILE
echo "[CHAOS] Concluído. Verifique 'df -h'."
echo "[CHAOS] Para remediar, execute: sudo remediate"
EOF

chmod +x /usr/local/bin/chaos-maker

# ------------------------------------------------------------------
# 5. Finalização
# ------------------------------------------------------------------
mkdir -p /var/log/journal
sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
systemctl restart systemd-journald

echo "[SUCCESS] Provisionamento concluído."