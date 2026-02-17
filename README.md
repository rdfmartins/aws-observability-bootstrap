# AWS Observability & Resilience Bootstrap: O Ciclo do Caos

Este projeto implementa uma infraestrutura resiliente na AWS, focada na resolução automatizada de incidentes de exaustão de recursos (Disk Full). Através de uma abordagem de Engenharia de Caos, validamos como o Logrotate e o CloudWatch Agent atuam na manutenção da disponibilidade de um servidor Nginx.

## 1. Estrutura do Projeto
```bash
├── terraform/          # Infraestrutura como Código (IaC)
│   ├── asg.tf          # Configuração de Auto Scaling e Elasticidade
│   ├── cloudwatch.tf   # Definição de Alarmes de Disco e Memória
│   ├── compute.tf      # Launch Template, AMI e User Data
│   ├── data.tf         # Data Sources (VPC, Subnets, Tags)
│   ├── iam.tf          # Permissões de Segurança (SSM, CW Agent)
│   ├── security.tf     # Firewall (Security Groups)
│   └── provider.tf     # Configuração AWS e Tags de FinOps
├── scripts/            # Scripts de Automação
│   ├── setup.sh        # Bootstrap completo (Nginx, Agentes, Configs)
│   └── chaos_maker.sh  # Ferramenta de injeção de falha (Disk Fill)
└── configs/            # Configurações de Aplicação
    └── nginx.logrotate # Regra de rotação e compressão de logs
```

## 2. Contexto Arquitetural (Engenharia Reversa)
Muitos incidentes de downtime em ambientes legados ocorrem por falhas triviais, como o preenchimento total do disco por logs de aplicação. 
Este projeto simula esse cenário crítico:
*   **O Problema:** Crescimento descontrolado de logs (`/var/log/nginx/access.log`).
*   **A Consequência:** Travamento do serviço Nginx e perda de visibilidade do monitoramento.
*   **A Solução:** Implementação de uma baseline de observabilidade (CloudWatch Agent) e uma política de sustentabilidade de disco (Logrotate).

## 2. Pilares da Solução
*   **Infraestrutura como Código (IaC):** Provisionamento completo via Terraform.
*   **Acesso Seguro:** Gerenciamento via **AWS Systems Manager (SSM)**, eliminando a necessidade de portas SSH (22) abertas e chaves `.pem`.
*   **Observabilidade Ativa:** Coleta de métricas de nível de SO (Disco e RAM) via CloudWatch Agent, cobrindo o "ponto cego" do Hypervisor.
*   **Automação de Manutenção:** Configuração idempotente de Logrotate para compressão e rotação diária.

## 3. O Ciclo do Game Day (Chaos Engineering)
Diferente de um setup passivo, este projeto inclui um fluxo completo de simulação de incidente:
1.  **Provisionamento:** A instância nasce monitorada e configurada com Nginx e CW Agent.
2.  **Injeção de Caos:** O script `chaos-maker` preenche o disco até ~98%.
3.  **Observação:** Monitoramento do Alarme de Disco no Console do CloudWatch.
4.  **Remediação:** Execução do comando `remediate` (atalho para `logrotate -f`) para recuperação imediata de espaço.

## 4. Estudo de Caso: Desafios de Engenharia (Nginx & Linux)

Este projeto vai além da infraestrutura básica. Ele resolve problemas reais de operação de sistemas Linux em nuvem:

### A. O Desafio da Corrida de Boot (Race Condition)
O script de *User Data* compete com o boot do sistema operacional. Se o Nginx tentar subir antes da rede estar pronta, ele falha.
*   **Solução:** Implementamos `systemctl enable --now nginx` estrategicamente após a instalação do pacote, garantindo que o serviço entre na árvore de dependências do `systemd` corretamente.

### B. O Dilema das Permissões (Root vs www-data)
O script de caos (`chaos-maker`) roda como `root` (sudo), mas o Nginx roda como `www-data` (segurança). Se o script criar o arquivo de log gigante com permissões de root, o Nginx trava por "Permission Denied" antes mesmo do disco encher.
*   **Solução:** O script aplica `chown www-data:adm` no arquivo gerado, garantindo que o teste simule **exaustão de recurso (disco)** e não **falha de permissão**.

### C. O Problema do Arquivo Fantasma (File Descriptors)
Em Linux, deletar um arquivo que está aberto por um processo (Nginx) **não libera espaço em disco**. O arquivo entra em estado "deleted but open".
*   **Solução:** Utilizamos a diretiva `postrotate` com `systemctl reload nginx` no Logrotate. Isso força o Nginx a fechar o descritor de arquivo antigo e abrir um novo, efetivamente liberando o espaço em disco.

## 5. Estratégia de Métricas (Deep Dive: CloudWatch Dimensions)

A integração entre Agente e Alarme exigiu uma "cirurgia" nas dimensões métricas:

*   **O Desafio (Métricas Órfãs):** Por padrão, o CloudWatch Agent envia métricas de disco com as dimensões `device` (ex: `xvda1`) e `fstype` (ex: `ext4`). O Alarme criado via Terraform, no entanto, é agnóstico à infraestrutura subjacente e espera apenas `AutoScalingGroupName` e `path`.
*   **O Resultado:** O Alarme nunca disparava porque as dimensões não davam "Match Exato".
*   **A Solução:** Configuramos o Agente com `drop_device: true` e `aggregation_dimensions`. Isso instrui o Agente a remover os detalhes de hardware e emitir uma métrica "limpa", agregada por ASG, permitindo que um único alarme monitore qualquer tipo de instância (T2, T3, C5) sem ajustes manuais.

## 6. Comandos Úteis (SRE Toolbox)
*   **Desafio:** O CloudWatch nativo monitora apenas métricas de Hypervisor (CPU, Rede), ignorando o uso de Disco e RAM.
*   **Solução:** Implementação de **Custom Metrics** via CloudWatch Agent (Métricas de OS-Level).
*   **Agregação por ASG:** O agente envia dimensões de `AutoScalingGroupName`. Isso permite criar alarmes consolidados que sobrevivem à efemeridade das instâncias.

> **Bônus (Observabilidade Estendida):** Além do foco principal em Disco, implementamos também o monitoramento de **Memória (RAM)**. Embora não seja o foco do teste de caos, essa métrica compõe o *baseline* essencial de saúde do sistema operacional, cobrindo os dois principais "pontos cegos" do hypervisor da AWS.

## 6. Comandos Úteis (SRE Toolbox)
Após conectar via SSM, utilize os comandos customizados:
*   `chaos-maker`: Simula a exaustão de disco.
*   `remediate`: Força a rotação de logs e libera espaço.
*   `df -h /`: Valida a recuperação do sistema.

## 6. Tecnologias Utilizadas
*   **AWS Cloud:** EC2, Auto Scaling, IAM, CloudWatch, SSM.
*   **IaC:** Terraform (validado com `fmt`, `validate` e `tflint`).
*   **Serviços:** Nginx (habilitado no boot), Logrotate, CloudWatch Agent.

## 9. Troubleshooting (Runbook)

### A. Alarme em "Insufficient Data"
*   **Sintoma:** O Alarme de Disco permanece sem dados no CloudWatch.
*   **Causa:** Incompatibilidade de dimensões. O Alarme espera apenas `AutoScalingGroupName`, mas o Agente pode estar enviando dimensões extras de hardware (`device`, `fstype`).
*   **Solução:** Validar no `setup.sh` se `drop_device` e `drop_fstype` estão como `true`. Use `aws cloudwatch list-metrics` para confirmar as dimensões que o CloudWatch está recebendo.

### B. Disco Cheio após Remediação Manual
*   **Sintoma:** O comando `remediate` roda, mas o espaço em disco não é liberado.
*   **Causa:** O processo do Nginx mantém o descritor de arquivo aberto (*deleted but open*).
*   **Solução:** Verifique se o comando `systemctl reload nginx` foi executado pelo `postrotate`. Utilize `lsof | grep deleted` para identificar arquivos zumbis segurando o espaço.

## 10. Limitações e Declaração de Escopo (Integridade Técnica)
Este projeto é um **Laboratório de Conceito (PoC)** e não deve ser utilizado em produção sem as seguintes melhorias:
*   **Segurança:** Utiliza HTTP na porta 80. Para produção, implementar Application Load Balancer (ALB) com certificado SSL (ACM).
*   **Rede:** Provisionado em Default VPC para simplicidade. Recomenda-se o uso de Subnets Privadas com NAT Gateway.
*   **Persistência de Logs:** Os logs rotacionados permanecem em disco. Para conformidade a longo prazo, deve-se implementar o streaming para S3 ou CloudWatch Logs.

## 6. Considerações de FinOps
A infraestrutura foi desenhada para se manter dentro do **AWS Free Tier** sempre que possível:
*   **Instância:** Sugerida `t3.micro` (ou `t2.micro`).
*   **Monitoramento:** Métricas personalizadas do CloudWatch Agent podem gerar custos após o limite gratuito.
*   **Cleanup:** Utilize `terraform destroy` após os testes para evitar custos residuais.
