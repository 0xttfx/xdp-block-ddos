#!/bin/bash
set -e

# Verifica se o bpftool está instalado
if ! command -v bpftool &> /dev/null; then
    echo "bpftool não encontrado. Instale bpftool e tente novamente."
    exit 1
fi

# Verificação de privilégios: alguns comandos podem solicitar senha via sudo
if [ "$EUID" -ne 0 ]; then
    echo "Atenção: comandos que exigem privilégios de root poderão solicitar sua senha."
fi

echo "=== Teste: Verificando a existência do arquivo objeto ==="
if [ ! -f xdp-block-dos.o ]; then
    echo "Erro: Arquivo 'xdp-block-dos.o' não encontrado. Compile o programa primeiro."
    exit 1
fi
echo "Arquivo objeto encontrado."

# Define o caminho de fixação (pin) do programa eBPF
PIN_PATH="/sys/fs/bpf/xdp_block_dos"

echo "=== Teste: Carregando o programa XDP com bpftool ==="
# Carrega o programa XDP e o fixa (pin) no sistema de arquivos BPF
sudo bpftool prog load xdp-block-dos.o $PIN_PATH type xdp
echo "Programa XDP carregado e fixado em: $PIN_PATH"

echo "=== Teste: Verificando se o programa está carregado ==="
# Verifica se o programa aparece na listagem de programas carregados
if sudo bpftool prog show | grep -q xdp_block_dos; then
    echo "Programa XDP identificado nos programas carregados."
else
    echo "Erro: Programa XDP não encontrado na listagem."
    exit 1
fi

echo "=== Teste: Desanexando e removendo o programa XDP ==="
# Remove o objeto fixado para limpar o ambiente
sudo rm $PIN_PATH
echo "Programa XDP removido com sucesso."

echo "Teste concluído com sucesso!"



