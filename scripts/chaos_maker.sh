#!/bin/bash
# chaos_maker.sh
# ATENÇÃO: ESTE SCRIPT FOI PROJETADO PARA ENCHER O DISCO PARA FINS DE TESTE DE OBSERVABILIDADE.
# NÃO EXECUTE EM AMBIENTES DE PRODUÇÃO CRÍTICOS SEM SUPERVISÃO.

LOG_FILE="/var/log/nginx/access.log"

echo "[CHAOS] Iniciando simulação de incidente de disco cheio..."

# Verifica espaço disponível na raiz (em KB)
AVAILABLE_SPACE=$(df / --output=avail | tail -1)

# Queremos deixar apenas 500MB livres para não travar o sistema operacional completamente
BUFFER_KB=500000
FILL_AMOUNT_KB=$((AVAILABLE_SPACE - BUFFER_KB))

if [ $FILL_AMOUNT_KB -le 0 ]; then
    echo "[CHAOS] O disco já está perigosamente cheio. Abortando para segurança."
    exit 1
fi

echo "[CHAOS] Espaço livre detectado: $(($AVAILABLE_SPACE / 1024)) MB"
echo "[CHAOS] Alvo: Preencher $(($FILL_AMOUNT_KB / 1024)) MB com dados 'lixo' em $LOG_FILE"
echo "[CHAOS] O Nginx deve começar a reclamar em breve..."

# Cria o arquivo gigante instantaneamente usando fallocate (muito mais rápido que dd)
# Se fallocate falhar (sistema de arquivos não suportar), usa head /dev/urandom
if command -v fallocate > /dev/null; then
    fallocate -l ${FILL_AMOUNT_KB}K $LOG_FILE
else
    head -c ${FILL_AMOUNT_KB}K < /dev/zero >> $LOG_FILE
fi

echo "[CHAOS] Concluído! Verifique o uso de disco com 'df -h'."
echo "[CHAOS] Agora aguarde o Alarme do CloudWatch disparar!"
