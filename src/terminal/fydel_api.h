#ifndef FYDEL_API_H
#define FYDEL_API_H

#ifdef __cplusplus
extern "C" {
#endif

/* Funções em Assembly */
int  pty_iniciar(int *fd_mestre, int *fd_escravo);
int  pty_obter_mestre(void);
void pty_loop(int fd_mestre);
void pty_fechar(void);

/* Funções em C */
int  verificar_drivers(void);
int  verificar_montagem_pts(void);
int  verificar_permissoes(void);
long obter_uso_cpu(void);
long obter_uso_ram(void);
long obter_uso_disco(void);
long obter_velocidade_rede(void);

#ifdef __cplusplus
}
#endif

#endif