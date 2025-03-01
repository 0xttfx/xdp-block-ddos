# Makefile para compilar o programa XDP com eBPF e gerenciar testes

# Utiliza o clang para compilação de programas eBPF
BPF_CLANG   = clang
# Flags de compilação: otimização, target bpf, avisos e erros para qualidade
BPF_CFLAGS  = -O2 -target bpf -c -Wall -Werror
SRC         = src/xdp_ddos_blocker.c
OBJ         = xdp_ddos_blocker.o

.PHONY: all clean test

# Target padrão: compila o programa eBPF
all: $(OBJ)

$(OBJ): $(SRC)
	$(BPF_CLANG) $(BPF_CFLAGS) $< -o $@

# Limpeza: remove arquivo objeto e, se existir, o arquivo fixado no BPF filesystem.
clean:
	rm -f $(OBJ)
	@if [ -e /sys/fs/bpf/xdp_ddos_blocker ]; then \
		echo "Removendo programa fixado em /sys/fs/bpf/xdp_ddos_blocker..."; \
		sudo rm /sys/fs/bpf/xdp_ddos_blocker; \
	fi

# Target de teste: compila e executa o script de testes.
test: all
	@chmod +x tests/test_xdp_ddos_blocker.sh
	./tests/test_xdp_ddos_blocker.sh



