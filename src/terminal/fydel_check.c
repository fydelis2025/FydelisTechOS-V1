#include "fydel_api.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
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

/* Verifica se o sistema de arquivos /dev/pts está montado (Melhorado para ISO Live) */
int verificar_montagem_pts(void) {
    FILE *arquivo = fopen("/proc/mounts", "r");
    int montado = 0;

    if (arquivo) {
        char linha[256];
        while (fgets(linha, sizeof(linha), arquivo)) {
            if (strstr(linha, "/dev/pts")) {
                montado = 1;
                break;
            }
        }
        fclose(arquivo);
    }

    // Se falhar no ambiente Live do Debian, tenta forçar a montagem se formos root
    if (!montado && getuid() == 0) {
        if (system("mount -t devpts devpts /dev/pts -o gid=5,mode=620 &>/dev/null") == 0) {
            return 1;
        }
    }

    return montado;
}

/* Verifica permissão para executar o shell */
int verificar_permissoes(void) {
    return access("/bin/bash", X_OK) == 0 ? 1 : 0;
}

/* Calcula uso de CPU */
long obter_uso_cpu(void) {
    static long ant_total = 0, ant_ocupado = 0;
    long total = 0, ocupado = 0;

    FILE *stat = fopen("/proc/stat", "r");
    if (!stat) return 0;

    char linha[256];
    if (!fgets(linha, sizeof(linha), stat)) { fclose(stat); return 0; }
    fclose(stat);

    long u, n, s, i, w, irq, sirq;
    if (sscanf(linha, "cpu %ld %ld %ld %ld %ld %ld %ld", &u, &n, &s, &i, &w, &irq, &sirq) < 7) return 0;

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

    if (total == 0) return 0;
    long usado = total - disponivel;
    return (usado * 100) / total;
}

/* Calcula uso de disco na raiz */
long obter_uso_disco(void) {
    struct statvfs vfs;
    if (statvfs("/", &vfs) != 0) return 0;

    long total = vfs.f_blocks * vfs.f_frsize;
    long livre = vfs.f_bfree * vfs.f_frsize;
    if (total == 0) return 0;

    return ((total - livre) * 100) / total;
}

/* Obtém velocidade de rede fictícia/amostra */
long obter_velocidade_rede(void) {
    return 45; // Em Mbps para amostragem no dashboard
}
