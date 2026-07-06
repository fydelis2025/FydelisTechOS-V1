#include "fydel_api.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <string.h>
#include <errno.h>

/* Verifica se os dispositivos PTY existem e têm permissão */
int verificar_drivers(void) {
    if (access("/dev/ptmx", R_OK | W_OK) != 0) return 0;
    if (access("/dev/pts", F_OK) != 0) return 0;
    return 1;
}

/* Verifica se o sistema de arquivos /dev/pts está montado */
int verificar_montagem_pts(void) {
    FILE *arquivo = fopen("/proc/mounts", "r");
    if (!arquivo) return 0;

    char linha[256];
    int montado = 0;
    while (fgets(linha, sizeof(linha), arquivo)) {
        if (strstr(linha, "/dev/pts") && strstr(linha, "devpts")) {
            montado = 1;
            break;
        }
    }
    fclose(arquivo);
    return montado;
}

/* Verifica permissão para executar o shell */
int verificar_permissoes(void) {
    return access("/bin/bash", X_OK) == 0 ? 1 : 0;
}

/* Calcula uso real da CPU */
long obter_uso_cpu(void) {
    static long ant_total = 0, ant_ocupado = 0;
    long total = 0, ocupado = 0;
    FILE *stat = fopen("/proc/stat", "r");
    if (!stat) return 0;

    char linha[256];
    if (!fgets(linha, sizeof(linha), stat)) { fclose(stat); return 0; }
    fclose(stat);

    long u, n, s, i, w, irq, sirq;
    sscanf(linha, "cpu %ld %ld %ld %ld %ld %ld %ld", &u, &n, &s, &i, &w, &irq, &sirq);

    total = u + n + s + i + w + irq + sirq;
    ocupado = u + n + s;

    if (ant_total == 0) { ant_total = total; ant_ocupado = ocupado; return 0; }

    long delta_total = total - ant_total;
    long delta_ocupado = ocupado - ant_ocupado;
    ant_total = total; ant_ocupado = ocupado;

    return delta_total ? (delta_ocupado * 100) / delta_total : 0;
}

/* Calcula uso real da memória RAM */
long obter_uso_ram(void) {
    long total = 0, disponivel = 0;
    FILE *meminfo = fopen("/proc/meminfo", "r");
    if (!meminfo) return 0;

    char linha[256];
    while (fgets(linha, sizeof(linha), meminfo)) {
        if (strstr(linha, "MemTotal:")) sscanf(linha, "MemTotal: %ld kB", &total);
        if (strstr(linha, "MemAvailable:")) sscanf(linha, "MemAvailable: %ld kB", &disponivel);
    }
    fclose(meminfo);

    return total ? ((total - disponivel) * 100) / total : 0;
}

/* Calcula uso do disco raiz */
long obter_uso_disco(void) {
    struct statvfs info;
    if (statvfs("/", &info) != 0) return 0;
    long total = info.f_blocks * info.f_frsize;
    long livre = info.f_bfree * info.f_frsize;
    return total ? ((total - livre) * 100) / total : 0;
}

/* Retorna velocidade aproximada da rede */
long obter_velocidade_rede(void) {
    return 12400; // Valor base, pode ser substituído por leitura de /proc/net/dev
}