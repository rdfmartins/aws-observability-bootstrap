# AWS Observability & Resilience Bootstrap: O Ciclo do Caos

Este projeto implementa uma infraestrutura resiliente na AWS, focada na resolução automatizada de incidentes de exaustão de recursos (Disk Full). Através de uma abordagem de Engenharia de Caos, validamos como o Logrotate e o CloudWatch Agent atuam na manutenção da disponibilidade de um servidor Nginx.

## 1. Contexto Arquitetural (Engenharia Reversa)
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

## 5. Estratégia de Monitoramento (ADR - Architectural Decision Record)
*   **Desafio:** O CloudWatch nativo monitora apenas métricas de Hypervisor (CPU, Rede), ignorando o uso de Disco e RAM.
*   **Solução:** Implementação de **Custom Metrics** via CloudWatch Agent (Métricas de OS-Level).
*   **Agregação por ASG:** O agente envia dimensões de `AutoScalingGroupName`, `ImageId` e `InstanceType`. Isso permite criar alarmes consolidados que sobrevivem à efemeridade das instâncias.

## 5. Comandos Úteis (SRE Toolbox)
Após conectar via SSM, utilize os comandos customizados:
*   `chaos-maker`: Simula a exaustão de disco.
*   `remediate`: Força a rotação de logs e libera espaço.
*   `df -h /`: Valida a recuperação do sistema.

## 6. Tecnologias Utilizadas
*   **AWS Cloud:** EC2, Auto Scaling, IAM, CloudWatch, SSM.
*   **IaC:** Terraform (validado com `fmt`, `validate` e `tflint`).
*   **Serviços:** Nginx (habilitado no boot), Logrotate, CloudWatch Agent.

## 7. Limitações e Declaração de Escopo (Integridade Técnica)
Este projeto é um **Laboratório de Conceito (PoC)** e não deve ser utilizado em produção sem as seguintes melhorias:
*   **Segurança:** Utiliza HTTP na porta 80. Para produção, implementar Application Load Balancer (ALB) com certificado SSL (ACM).
*   **Rede:** Provisionado em Default VPC para simplicidade. Recomenda-se o uso de Subnets Privadas com NAT Gateway.
*   **Persistência de Logs:** Os logs rotacionados permanecem em disco. Para conformidade a longo prazo, deve-se implementar o streaming para S3 ou CloudWatch Logs.

## 6. Considerações de FinOps
A infraestrutura foi desenhada para se manter dentro do **AWS Free Tier** sempre que possível:
*   **Instância:** Sugerida `t3.micro` (ou `t2.micro`).
*   **Monitoramento:** Métricas personalizadas do CloudWatch Agent podem gerar custos após o limite gratuito.
*   **Cleanup:** Utilize `terraform destroy` após os testes para evitar custos residuais.
