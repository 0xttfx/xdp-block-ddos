# Makefile para compilar o programa XDP com eBPF e gerenciar testes

# Verifica se as ferramentas necessárias estão instaladas
CLANG ?= clang
BPFTOOL ?= bpftool
LLC ?= llc

# Verifica versão mínima do CLANG (necessária para BPF CO-RE)
CLANG_VERSION = $(shell $(CLANG) --version | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
CLANG_MAJOR = $(shell echo $(CLANG_VERSION) | cut -d'.' -f1)
REQ_CLANG_MAJOR = 10

# Flags de compilação
BPF_CFLAGS = -O2 -g -target bpf -c -Wall -Werror

# Arquivos fonte e objeto
SRC = $(wildcard src/xdp-block-dos*.c)
TEST_SCRIPT = $(wildcard tests/test-xdp-block-dos*.sh)
OBJ = xdp-block-dos.o

.PHONY: all clean test

check_single_source:
	@if [ $$(echo $(SRC) | wc -w) -ne 1 ]; then \
		echo "Error: Found multiple or no source files matching pattern"; \
		echo "Files found: $(SRC)"; \
		exit 1; \
	fi
	@if [ $$(echo $(TEST_SCRIPT) | wc -w) -ne 1 ]; then \
		echo "Error: Found multiple or no test script matching pattern"; \
		echo "Files found: $(TEST_SCRIPT)"; \
		exit 1; \
	fi

# Verifica requisitos antes de compilar
all: check_requirements check_single_source $(OBJ)

check_requirements:
	@if [ $(CLANG_MAJOR) -lt $(REQ_CLANG_MAJOR) ]; then \
		echo "Error: clang version >= $(REQ_CLANG_MAJOR) required"; \
		exit 1; \
	fi
	@which $(BPFTOOL) > /dev/null || (echo "Error: bpftool not found"; exit 1)

$(OBJ): $(SRC)
	$(CLANG) $(BPF_CFLAGS) $< -o $@

clean:
	rm -f $(OBJ)
	@if [ -e /sys/fs/bpf/blocked_ips ]; then \
		echo "Removendo mapa pinado..."; \
		sudo rm /sys/fs/bpf/blocked_ips; \
	fi

test: all
	@chmod +x $(TEST_SCRIPT)
	./$(TEST_SCRIPT)



