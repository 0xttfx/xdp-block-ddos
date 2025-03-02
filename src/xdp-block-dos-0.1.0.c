#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

/*
 * Mapa do tipo HASH para armazenar os IPs bloqueados.
 * - Chave: __u32 (IP de origem, em formato de rede, em big-endian)
 * - Valor: __u32 (flag, por exemplo, 1 para indicar bloqueio)
 * - max_entries: define quantos IPs podem ser bloqueados simultaneamente
 */
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} blocked_ips SEC(".maps");

/*
 * Programa XDP para bloquear pacotes provenientes de IPs listados no mapa.
 *
 * Fluxo do programa:
 *   1. Obtém os ponteiros para o início e fim dos dados do pacote.
 *   2. Valida a presença completa do cabeçalho Ethernet.
 *   3. Processa somente pacotes IPv4.
 *   4. Valida a presença do cabeçalho IP completo e a integridade do campo IHL.
 *   5. Extrai o IP de origem (localizado nos primeiros 20 bytes do cabeçalho IP).
 *   6. Consulta o mapa 'blocked_ips' e, se o IP estiver bloqueado, retorna XDP_DROP.
 *      Caso contrário, o pacote segue normalmente (XDP_PASS).
 *
 * Detalhes de performance:
 *   - A execução ocorre no caminho de dados (driver) com alta performance e baixa latência.
 *   - As verificações de limites são essenciais para satisfazer o verificador do eBPF.
 *   - A lógica foi mantida mínima, sem operações adicionais, para otimizar o tempo de execução.
 */
SEC("xdp")
int xdp_ddos_blocker(struct xdp_md *ctx)
{
    // Obtém os ponteiros para os dados do pacote
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    // Verifica se o cabeçalho Ethernet está completo
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    // Processa somente pacotes IPv4
    if (bpf_ntohs(eth->h_proto) != ETH_P_IP)
        return XDP_PASS;

    // Calcula o início do cabeçalho IP (logo após o cabeçalho Ethernet)
    struct iphdr *ip = data + sizeof(*eth);
    
    // Verifica se pelo menos os 20 bytes mínimos do cabeçalho IP estão presentes.
    if ((void *)ip + sizeof(struct iphdr) > data_end)
        return XDP_PASS;

    // Valida o campo IHL: deve ser pelo menos 5 (5 * 4 = 20 bytes).
    if (ip->ihl < 5)
        return XDP_PASS;
    
    // Opcional: verificação completa do cabeçalho IP, considerando opções se presentes.
    if ((void *)ip + (ip->ihl * 4) > data_end)
        return XDP_PASS;

    // Extrai o IP de origem (localizado nos primeiros 20 bytes e sempre presente se ip->ihl >= 5)
    __u32 src_ip = ip->saddr;

    // Consulta no mapa: se o IP de origem estiver presente, descarta o pacote.
    __u32 *blocked = bpf_map_lookup_elem(&blocked_ips, &src_ip);
    if (blocked)
        return XDP_DROP;

    return XDP_PASS;
}

// Obrigatório: licença do programa eBPF, necessária para que o kernel aceite o carregamento.
char _license[] SEC("license") = "GPL";

