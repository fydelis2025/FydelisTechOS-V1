section .data
    ; Números de chamadas de sistema Linux x86_64
    SYS_READ        equ 0
    SYS_WRITE       equ 1
    SYS_OPEN        equ 2
    SYS_CLOSE       equ 3
    SYS_DUP2        equ 33
    SYS_EXECVE      equ 59
    SYS_EXIT        equ 60
    SYS_IOCTL       equ 16
    SYS_SETSID      equ 112
    SYS_FORK        equ 57
    SYS_SELECT      equ 23

    ; Constantes PTY
    TIOCGPTN        equ 0x80045430
    TIOCSPTLCK      equ 0x40045431
    TIOCSCTTY       equ 0x540E
    O_RDWR          equ 2
    STDIN           equ 0
    STDOUT          equ 1
    STDERR          equ 2

    ptmx_path       db "/dev/ptmx", 0
    pts_base        db "/dev/pts/", 0
    sh_path         db "/bin/bash", 0

section .bss
    fd_mestre       resq 1
    fd_escravo      resq 1
    pty_num         resd 1
    pts_path        resb 64

section .text
    global pty_iniciar, pty_obter_mestre, pty_loop, pty_fechar

; int pty_iniciar(int *fd_mestre, int *fd_escravo);
pty_iniciar:
    push rbx
    mov r12, rdi        ; Ponteiro para fd_mestre
    mov r13, rsi        ; Ponteiro para fd_escravo

    ; Abrir /dev/ptmx
    mov rax, SYS_OPEN
    mov rdi, ptmx_path
    mov rsi, O_RDWR
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .erro
    mov [fd_mestre], rax

    ; Desbloquear PTY
    mov rax, SYS_IOCTL
    mov rdi, [fd_mestre]
    mov rsi, TIOCSPTLCK
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .erro

    ; Obter número do PTY
    mov rax, SYS_IOCTL
    mov rdi, [fd_mestre]
    mov rsi, TIOCGPTN
    mov rdx, pty_num
    syscall
    cmp rax, 0
    jl .erro

    ; Montar caminho /dev/pts/N
    mov rsi, pts_base
    mov rdi, pts_path
.copia_base:
    lodsb
    test al, al
    jz .converte_num
    stosb
    jmp .copia_base

.converte_num:
    mov eax, [pty_num]
    mov ecx, 10
    push 0
.digito:
    xor edx, edx
    div ecx
    add dl, '0'
    push rdx
    test eax, eax
    jnz .digito

.escreve_num:
    pop rax
    test al, al
    jz .finaliza_caminho
    stosb
    jmp .escreve_num

.finaliza_caminho:
    mov byte [rdi], 0

    ; Abrir lado escravo
    mov rax, SYS_OPEN
    mov rdi, pts_path
    mov rsi, O_RDWR
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .erro
    mov [fd_escravo], rax

    ; Retornar valores
    mov eax, [fd_mestre]
    mov [r12], eax
    mov eax, [fd_escravo]
    mov [r13], eax
    xor rax, rax
    pop rbx
    ret

.erro:
    mov rax, -1
    pop rbx
    ret

; int pty_obter_mestre(void);
pty_obter_mestre:
    mov eax, [fd_mestre]
    ret

; void pty_loop(int fd_mestre);
pty_loop:
    push rbx
    push rbp
    mov rbx, rdi            ; Guardar rdi (fd_mestre) em rbx

    ; Alocação do stack frame para o buffer (4096 bytes) + fd_set (128 bytes)
    ; Total alocado no stack: 4224 bytes
    sub rsp, 4224
    lea rbp, [rsp + 128]    ; rbp aponta para o início do buffer de dados
                            ; rsp aponta para a estrutura do fd_set (128 bytes)

.loop:
    ; --- CONFIGURAR FD_SET (MÁSCARA DE BITS) ---
    ; Zera os 128 bytes (1024 bits) do fd_set
    mov rdi, rsp
    xor rax, rax
    mov rcx, 16             ; 16 quadwords = 128 bytes
    rep stosq

    ; Setar bit do STDIN (bit 0) no fd_set
    mov rax, [rsp]
    bts rax, 0
    mov [rsp], rax

    ; Setar bit do fd_mestre no fd_set
    mov rcx, rbx            ; Número do fd_mestre
    shr rcx, 6              ; Dividir por 64 para achar em qual qword ele está
    shl rcx, 3              ; Multiplicar por 8 (offset em bytes)
    lea rdi, [rsp + rcx]
    
    mov rdx, rbx
    and rdx, 63             ; Pega o resto (posição exata do bit)
    mov rax, [rdi]
    bts rax, rdx            ; Liga o bit correspondente ao fdmestre
    mov [rdi], rax

    ; --- CHAMADA SYS_SELECT ---
    mov rdi, rbx
    inc rdi                 ; nfds = fd_mestre + 1
    mov rsi, rsp            ; readfds apontando para o stack
    xor rdx, rdx            ; writefds = NULL
    xor r10, r10            ; exceptfds = NULL
    xor r8, r8              ; timeout = NULL (bloqueante)
    mov rax, SYS_SELECT
    syscall

    cmp rax, 0
    jle .fim                ; Se erro ou interrupção, finaliza

    ; --- VERIFICAR SE FOI ENTRADA DO TECLADO (STDIN) ---
    mov rax, [rsp]
    bt rax, 0
    jnc .checar_mestre

    ; Ler do teclado
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, rbp
    mov rdx, 4096
    syscall
    cmp rax, 0
    jle .fim

    ; Escrever no PTY
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, rbx
    mov rsi, rbp
    syscall

.checar_mestre:
    ; --- VERIFICAR SE FOI SAÍDA DO PTY MESTRE ---
    mov rcx, rbx
    shr rcx, 6
    shl rcx, 3
    lea rdi, [rsp + rcx]
    mov rdx, rbx
    and rdx, 63
    mov rax, [rdi]
    bt rax, rdx
    jnc .loop

    ; Ler do PTY MESTRE
    mov rax, SYS_READ
    mov rdi, rbx
    mov rsi, rbp
    mov rdx, 4096
    syscall
    cmp rax, 0
    jle .fim

    ; Escrever na tela (STDOUT)
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, rbp
    syscall

    jmp .loop

.fim:
    add rsp, 4224
    pop rbp
    pop rbx
    ret

; void pty_fechar(void);
pty_fechar:
    mov rax, SYS_CLOSE
    mov rdi, [fd_mestre]
    syscall
    mov rax, SYS_CLOSE
    mov rdi, [fd_escravo]
    syscall
    ret