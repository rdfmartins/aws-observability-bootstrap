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
Diferente de um setup passivo, este projeto inclui um script de simulação de falha:
1.  **Provisionamento:** A instância nasce monitorada e configurada.
2.  **Injeção de Caos:** O script `chaos_maker.sh` preenche artificialmente o disco até 98%.
3.  **Observação:** Validação do disparo do Alarme no CloudWatch.
4.  **Remediação:** Execução do Logrotate para recuperação imediata de espaço e estabilização do serviço.

## 4. Tecnologias Utilizadas
*   **AWS Cloud:** EC2, Auto Scaling, IAM, CloudWatch, SSM.
*   **IaC:** Terraform.
*   **Serviços:** Nginx, Logrotate, CloudWatch Agent.
*   **Scripts:** Bash (Setup e Chaos Generation).

## 5. Limitações e Declaração de Escopo (Integridade Técnica)
Este projeto é um **Laboratório de Conceito (PoC)** e não deve ser utilizado em produção sem as seguintes melhorias:
*   **Segurança:** Utiliza HTTP na porta 80. Para produção, implementar Application Load Balancer (ALB) com certificado SSL (ACM).
*   **Rede:** Provisionado em Default VPC para simplicidade. Recomenda-se o uso de Subnets Privadas com NAT Gateway.
*   **Persistência de Logs:** Os logs rotacionados permanecem em disco. Para conformidade a longo prazo, deve-se implementar o streaming para S3 ou CloudWatch Logs.

## 6. Considerações de FinOps
A infraestrutura foi desenhada para se manter dentro do **AWS Free Tier** sempre que possível:
*   **Instância:** Sugerida `t3.micro` (ou `t2.micro`).
*   **Monitoramento:** Métricas personalizadas do CloudWatch Agent podem gerar custos após o limite gratuito.
*   **Cleanup:** Utilize `terraform destroy` após os testes para evitar custos residuais.
