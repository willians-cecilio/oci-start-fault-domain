# Script de Auto-Reparo para Instâncias OCI

Este script tenta iniciar uma instância OCI e, se a instância não ficar no estado `RUNNING` em 5 minutos, ele executa uma rotina de reparo trocando seu Fault Domain.

## Lógica de Execução
1.  **Tentativa de Início:** O script primeiro tenta iniciar a instância especificada e aguarda até 5 minutos para que ela atinja o estado `RUNNING`.
2.  **Verificação de Sucesso:**
    - Se a instância iniciar com sucesso, o script exibe uma mensagem de sucesso e termina.
    - Se a instância não iniciar no tempo esperado, o script assume que ela está com problemas e inicia a sequência de reparo.
3.  **Sequência de Reparo:**
    - **Parada Forçada:** Garante que a instância esteja totalmente no estado `STOPPED`.
    - **Rotação de Fault Domain:** Altera o Fault Domain da instância na seguinte ordem:
        - `FAULT-DOMAIN-1` -> `FAULT-DOMAIN-2`
        - `FAULT-DOMAIN-2` -> `FAULT-DOMAIN-3`
        - `FAULT-DOMAIN-3` -> `FAULT-DOMAIN-1`
    - **Nova Tentativa de Início:** Após a troca do Fault Domain, o script tenta iniciar a instância uma última vez.
    - O script reportará o sucesso ou a falha desta etapa final.

## Como Usar
```bash
./faultdomain.sh <instance-id>
```
**Exemplo:**
```bash
./faultdomain.sh ocid1.instance.oc1.iad.xxxxxxxxxxxxxxxxx
```
O script é ideal para ser usado em um `crontab` para monitorar e reparar instâncias que falham ao iniciar.

## Dependências
- [OCI CLI](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm) - A CLI da Oracle Cloud deve estar instalada e configurada.
- [jq](https://stedolan.github.io/jq/download/) - Um processador JSON de linha de comando.
