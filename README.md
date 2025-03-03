# xdp-block-dos
playing with XDP and eBPF to mitigate a DDoS attack


Este programa em C exemplifica um programa XDP (eXpress Data Path) desenvolvido com eBPF (extended Berkeley Packet Filter) para filtragem de pacotes. O XDP permite o processamento de pacotes na camada de driver de rede, garantindo alta performance e baixa latência, o que é fundamental para aplicações críticas como a mitigação de ataques DDoS.

O programa atua interceptando cada pacote recebido, realizando uma série de verificações:

    Integridade dos cabeçalhos: Valida se os cabeçalhos Ethernet e IPv4 estão completos e corretos, garantindo que apenas pacotes válidos sejam processados.
    Extração do IP de origem: Após confirmar a validade do cabeçalho, o programa extrai o endereço IP de origem do pacote.
    Verificação em mapa hash: Utiliza um mapa do tipo hash para armazenar os IPs bloqueados. Se o IP de origem constar nesse mapa, o pacote é descartado (XDP_DROP); caso contrário, ele é permitido seguir seu fluxo normal (XDP_PASS).


## Estrutura do Projeto

- **src/**: Código-fonte do programa.
- **tests/**: Scripts de teste para verificar a compilação e carregamento do programa.
- **Makefile**: Arquivo para compilar, limpar e executar testes.

## Requisitos

- Clang/LLVM (suporte a compilação para eBPF)
- bpftool
- Acesso root (para carregar o programa XDP)

## Compilação

Para compilar o programa, execute:

```bash
make all
```

## Testes

Para rodar os testes, execute:

```bash
make test
```

## Limpeza

Para remover os arquivos gerados, execute:

```bash
make clean
```

## Detalhes Técnicos

1. **Verificações de Segurança e Integridade:**
    
    - **Cabeçalho Ethernet:**  
        O código garante que o cabeçalho Ethernet completo esteja presente, comparando o ponteiro para o fim do cabeçalho com `data_end`.
    - **Cabeçalho IP:**
        - É verificado se pelo menos 20 bytes (o tamanho mínimo do cabeçalho IP) estão disponíveis.
        - Verificação para o campo `ihl` (Internet Header Length), garantindo que seja maior ou igual a 5.
        - Se o IP possuir opções (quando `ihl > 5`), o código valida que o cabeçalho completo (tamanho `ip->ihl * 4`) está dentro dos limites do buffer.

2. **Extração do IP de Origem:**
    
    - O IP de origem (`ip->saddr`) é extraído sem necessidade de cálculos adicionais, pois ele sempre se encontra nos primeiros 20 bytes do cabeçalho IP.

3. **Consulta no Mapa eBPF:**
    
    - O mapa `blocked_ips` é consultado utilizando o helper `bpf_map_lookup_elem`.
    - Se o ponteiro retornado for não nulo, isso indica que o IP está bloqueado e, consequentemente, o pacote é descartado com `XDP_DROP`.
    - Essa operação é extremamente rápida, pois o mapa foi definido para ter um acesso em tempo O(1) (tabela hash).

4. **Performance e Considerações de Otimização:**
    
    - **Execução no XDP:**  
        O programa é executado no XDP, logo na entrada dos pacotes, o que garante baixa latência e alta performance.
    - **Minimalismo:**  
        A lógica foi mantida mínima para reduzir o número de instruções e evitar qualquer latência adicional.
    - **Verificador eBPF:**  
        Todas as verificações de limites são necessárias para passar pelo verificador do kernel, garantindo que o programa seja seguro e não acesse memória fora dos limites.
    - **Possíveis Micro-Otimizações:**  
        Em cenários mais avançados, técnicas como _branch prediction hints_ (por meio de macros como `__builtin_expect`) podem ser consideradas, mas normalmente o compilador BPF já otimiza o código de forma eficaz.

5. **Licenciamento:**
    
    - A inclusão da string de licença `"GPL"` é obrigatória para o carregamento do programa no kernel.


## Compilando o Programa
Utilize o clang para compilar o programa para o formato eBPF:

```bash
clang -O2 -target bpf -c xdp_ddos_blocker.c -o xdp_ddos_blocker.o
```

## Carregando o Programa XDP na Interface de Rede
Com o programa compilado e o mapa devidamente configurado (e pinado), você pode carregar o programa XDP na interface de rede utilizando o utilitário `ip`:

```bash
ip link set dev eth0 xdp obj xdp_ddos_blocker.o sec xdp
```

Para verificar se o programa foi carregado corretamente, utilize:

```bash
ip -details link show dev eth0
```

Se necessário, para remover o programa XDP:

```bash
ip link set dev eth0 xdp off
```

## Dica de ouro

Eu sou um noob em C e por isso: teste a porra toda! E faça PR para me mostar como se faz direito!
Valeu!!!
