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

# Habilita e inicia o Nginx no bootstrap
systemctl enable --now nginx

# Baixa e instala o Amazon CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# ------------------------------------------------------------------
# 2. Configuração do Logrotate (A Vacina)
# ------------------------------------------------------------------
echo "[INFO] Configurando Logrotate..."
# Rotação diária com compressão imediata (sem delaycompress) para testes de Game Day
cat <<'EOF' > /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    rotate 14
    compress
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

# Cria um atalho para remediação manual durante simulações
echo '#!/bin/bash' > /usr/local/bin/remediate
echo 'logrotate -f -v /etc/logrotate.d/nginx' >> /usr/local/bin/remediate
chmod +x /usr/local/bin/remediate

# ------------------------------------------------------------------
# 3. Configuração do CloudWatch Agent (Métricas Agregadas)
# ------------------------------------------------------------------
echo "[INFO] Configurando CloudWatch Agent..."
# Agregação por ASG e remoção de dimensões de hardware (device/fstype) para match de alarme
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "aggregation_dimensions": [
            ["AutoScalingGroupName"]
        ],
        "append_dimensions": {
            "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
        },
        "metrics_collected": {
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["/"],
                "drop_device": true,
                "drop_fstype": true
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

# ------------------------------------------------------------------
# 4. Ferramenta de Caos (Chaos Engineering)
# ------------------------------------------------------------------
echo "[INFO] Instalando script chaos-maker em /usr/local/bin/..."
cat <<'EOF' > /usr/local/bin/chaos-maker
#!/bin/bash
LOG_FILE="/var/log/nginx/access.log"
AVAILABLE_SPACE=$(df / --output=avail | tail -1)
BUFFER_KB=500000
FILL_AMOUNT_KB=$((AVAILABLE_SPACE - BUFFER_KB))

if [ $FILL_AMOUNT_KB -le 0 ]; then
    echo "[CHAOS] Disco cheio."
    exit 1
fi

echo "[CHAOS] Injetando $((FILL_AMOUNT_KB / 1024)) MB em $LOG_FILE..."
fallocate -l ${FILL_AMOUNT_KB}K $LOG_FILE || head -c ${FILL_AMOUNT_KB}K < /dev/zero >> $LOG_FILE

# Garante permissões para o Nginx (www-data)
chown www-data:adm $LOG_FILE
chmod 640 $LOG_FILE

echo "[CHAOS] Concluído. Remediar com: sudo remediate"
EOF

chmod +x /usr/local/bin/chaos-maker

# ------------------------------------------------------------------
# 5. Finalização
# ------------------------------------------------------------------
mkdir -p /var/log/journal
sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
systemctl restart systemd-journald

echo "[SUCCESS] Provisionamento concluído."