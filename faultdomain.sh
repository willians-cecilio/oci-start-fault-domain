#!/bin/bash
# Script: faultdomain.sh
# Author: Willians Cecilio (https://github.com/willians-cecilio/oci-start-fault-domain)

echo "Iniciando script de auto-reparo de instância OCI..."

# Valida se o ID da instância foi passado como argumento
if [ -z "$1" ]; then
    echo "Usage: $0 <instance-id>"
    exit 1
fi

INSTANCE_ID="$1"

# Verifica se o jq está instalado
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it to run this script." >&2
    exit 1
fi

echo "Tentando iniciar a instância $INSTANCE_ID e aguardando até 5 minutos..."
oci compute instance action --action START --instance-id "$INSTANCE_ID" --wait-for-state RUNNING --max-wait-seconds 300 &> /dev/null
start_exit_code=$?

if [ $start_exit_code -eq 0 ]; then
    echo "Instância iniciada com sucesso."
    exit 0
else
    echo "Instância não iniciou em 5 minutos. Iniciando processo de reparo..."

    echo "Verificando o estado atual da instância..."
    output=$(oci compute instance get --instance-id "$INSTANCE_ID")
    state=$(echo "$output" | jq -r '.data."lifecycle-state"')
    echo "Estado atual é: $state"

    if [[ "$state" != "STOPPED" ]]; then
        echo "Instância não está parada. Forçando parada antes de alterar o Fault Domain..."
        oci compute instance action --action STOP --instance-id "$INSTANCE_ID" --wait-for-state STOPPED
        if [ $? -ne 0 ]; then
            echo "Falha ao parar a instância. Abortando." >&2
            exit 1
        fi
        echo "Instância parada com sucesso."
    fi

    # Lógica de rotação do Fault Domain
    output=$(oci compute instance get --instance-id "$INSTANCE_ID") # Obter dados novamente para garantir o FD mais recente
    fault_domain=$(echo "$output" | jq -r '.data."fault-domain"')
    echo "FD atual: $fault_domain"

    case "$fault_domain" in
        "FAULT-DOMAIN-1") new_domain="FAULT-DOMAIN-2" ;;
        "FAULT-DOMAIN-2") new_domain="FAULT-DOMAIN-3" ;;
        "FAULT-DOMAIN-3") new_domain="FAULT-DOMAIN-1" ;;
        *)
            echo "Fault Domain desconhecido ou não gerenciável: $fault_domain. Abortando." >&2
            exit 1
            ;;
    esac

    echo "Alterando o FD para: $new_domain"
    update_output=$(oci compute instance update --instance-id "$INSTANCE_ID" --fault-domain "$new_domain")
    if [ $? -ne 0 ]; then
        echo "Falha ao enviar o comando de atualização do FD." >&2
        exit 1
    fi

    work_request_id=$(echo "$update_output" | jq -r '."opc-work-request-id"')
    echo "Aguardando a conclusão da atualização do Fault Domain (Work Request ID: $work_request_id)..."
    oci work-requests work-request wait --work-request-id "$work_request_id" --wait-for-state SUCCEEDED
    if [ $? -ne 0 ]; then
        echo "A atualização do Fault Domain falhou." >&2
        exit 1
    fi
    echo "Fault Domain alterado com sucesso."

    echo "Tentando iniciar a instância novamente após o reparo..."
    oci compute instance action --action START --instance-id "$INSTANCE_ID" --wait-for-state RUNNING
    if [ $? -ne 0 ]; then
        echo "Reparo falhou. A instância não pôde ser iniciada após a troca do Fault Domain." >&2
        exit 1
    fi

    echo "Reparo bem-sucedido! A instância está agora no estado RUNNING."
    exit 0
fi

