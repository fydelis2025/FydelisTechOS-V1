section .data
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

    TIOCGPTN        equ 0x80045430
    TIOCSPTLCK      equ 0x40045431
    TIOCSCTTY       equ 0x540E
    O_RDWR          equ 2
    STDIN           equ 0
    STDOUT          equ 1
    STDERR          equ 2

    ptmx_path       db "/dev/ptmx", 0
    sh_path         db "/bin/bash", 0
    
    ; Timeout não-bloqueante para evitar deadlocks em ambientes CI (GitHub Actions)
    timeout_tv      dq 0, 50000  ; 0 segundos, 50ms microssegundos

section .bss
    fd_mestre       resq 1
    fd_escravo      resq 1
    pty_num         resd 1
    pts_path        resb 64
    argv            resq 2
    envp            resq 1

section .text
    global pty_iniciar, pty_obter_mestre, pty_loop, pty_fechar

pty_iniciar:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov r12, rdi            ; Salva ponteiro int* fd_mestre
    mov rbx, rsi            ; Salva ponteiro int* fd_escravo

    ; 1. Abrir /dev/ptmx
    mov rax, SYS_OPEN
    mov rdi, ptmx_path
    mov rsi, O_RDWR
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .erro
    mov [fd_mestre], rax
    mov dword [r12], eax    ; Retorna para o C++

    ; 2. Obter número do PTY (ioctl)
    mov rax, SYS_IOCTL
    mov rdi, [fd_mestre]
    mov rsi, TIOCGPTN
    mov rdx, pty_num
    syscall
    cmp rax, 0
    jl .erro_com_mestre

    ; 3. Desbloquear o PTY escravo
    xor rcx, rcx            ; Trava = 0 (desbloquear)
    push rcx
    mov rax, SYS_IOCTL
    mov rdi, [fd_mestre]
    mov rsi, TIOCSPTLCK
    mov rdx, rsp
    syscall
    pop rcx
    cmp rax, 0
    jl .erro_com_mestre

    ; 4. Formatar caminho do escravo (/dev/pts/X) com segurança
    xor rax, rax
    mov rdi, pts_path
    mov rcx, 64
    rep stosb               ; Limpa o buffer com zeros (Prevenção de Leak/Overflow)

    ; Escrita manual segura do path
    mov dword [pts_path], 0x7665642f     ; "/dev"
    mov dword [pts_path+4], 0x7374702f   ; "/pts"
    mov byte [pts_path+8], 0x2f          ; "/"

    mov eax, [pty_num]
    xor rdx, rdx
    mov ecx, 10
    lea rdi, [pts_path+15]               ; Escreve de trás para frente
.convert_loop:
    div ecx
    add edx, '0'
    dec rdi
    mov [rdi], dl
    xor rdx, rdx
    test eax, eax
    jnz .convert_loop

    ; Move a string formatada para o início correto
    lea rsi, [rdi]
    lea rdi, [pts_path+9]
.copy_str:
    lodsb
    stosb
    test al, al
    jnz .copy_str

    ; 5. Abrir o dispositivo Escravo gerado
    mov rax, SYS_OPEN
    lea rdi, [pts_path]
    mov rsi, O_RDWR
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .erro_com_mestre
    mov [fd_escravo], rax
    mov dword [rbx], eax    ; Retorna para o C++

    ; 6. Realizar o FORK com validação estrita
    mov rax, SYS_FORK
    syscall
    cmp rax, 0
    jl .erro_completo       ; Menor que 0 = Falha crítica no Kernel
    jz .processo_filho

    ; Processo Pai: Retorna com Sucesso (0)
    xor rax, rax
    pop r12
    pop rbx
    pop rbp
    ret

.processo_filho:
    ; Criar nova sessão de terminal isolada
    mov rax, SYS_SETSID
    syscall

    ; Atribuir terminal de controle
    mov rax, SYS_IOCTL
    mov rdi, [fd_escravo]
    mov rsi, TIOCSCTTY
    xor rdx, rdx
    syscall

    ; Redirecionar STDIN, STDOUT, STDERR para o escravo
    mov rax, SYS_DUP2
    mov rdi, [fd_escravo]
    mov rsi, STDIN
    syscall

    mov rax, SYS_DUP2
    mov rdi, [fd_escravo]
    mov rsi, STDOUT
    syscall

    mov rax, SYS_DUP2
    mov rdi, [fd_escravo]
    mov rsi, STDERR
    syscall

    ; Fechar descritores duplicados que sobraram
    mov rax, SYS_CLOSE
    mov rdi, [fd_mestre]
    syscall
    mov rax, SYS_CLOSE
    mov rdi, [fd_escravo]
    syscall

    ; Executar o Bash de forma limpa
    lea rdi, [sh_path]
    mov [argv], rdi
    mov qword [argv+8], 0
    mov qword [envp], 0

    lea rsi, [argv]
    lea rdx, [envp]
    mov rax, SYS_EXECVE
    syscall

    ; Se chegar aqui, o execve falhou
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

.erro_completo:
    mov rax, SYS_CLOSE
    mov rdi, [fd_escravo]
    syscall
.erro_com_mestre:
    mov rax, SYS_CLOSE
    mov rdi, [fd_mestre]
    syscall
.erro:
    mov rax, -1
    pop r12
    pop rbx
    pop rbp
    ret

pty_obter_mestre:
    mov rax, [fd_mestre]
    ret

pty_loop:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 4112           ; Aloca espaço no stack para buffer e fd_set

    mov rbx, rdi            ; rbx = fd_mestre

.loop_principal:
    ; Limpar e preencher fd_set no stack
    lea rdi, [rsp]
    mov rcx, 16
    xor rax, rax
    rep stosq

    ; Adicionar STDIN (0) e fd_mestre ao fd_set
    mov qword [rsp], 1      ; Liga o bit 0 (STDIN)
    mov rcx, rbx
    and rcx, 63
    mov rax, 1
    shl rax, cl
    
    mov rdx, rbx
    shr rdx, 6
    shl rdx, 3
    
    ; --- CORREÇÃO DO OR: Uso de registrador intermediário r10 para evitar combinação inválida ---
    mov r10, [rsp + rdx]
    or  r10, rax
    mov [rsp + rdx], r10

    ; Chamar SYS_SELECT com timeout seguro para a automação do GitHub
    mov rdi, rbx
    inc rdi                 ; nfds = fd_mestre + 1
    mov rsi, rsp
    xor rdx, rdx
    xor r10, r10
    lea r8, [timeout_tv]    ; Define o ponteiro de timeout (50ms)
    mov rax, SYS_SELECT
    syscall

    cmp rax, 0
    jl .fim                 ; Se erro real, sai do loop
    je .loop_principal      ; Se deu timeout sem dados, apenas repensa o loop (Evita travamento)

    ; Verificar STDIN
    mov rax, [rsp]
    bt rax, 0
    jnc .checar_mestre

    ; Ler entrada
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [rsp + 128]
    mov rdx, 4096
    syscall
    cmp rax, 0
    jle .fim

    ; Escrever no mestre
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [rsp + 128]
    syscall

.checar_mestre:
    mov rcx, rbx
    and rcx, 63
    mov rdx, rbx
    shr rdx, 6
    shl rdx, 3
    mov rax, qword [rsp + rdx]
    bt rax, cl
    jnc .loop_principal

    ; Ler do mestre
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [rsp + 128]
    mov rdx, 4096
    syscall
    cmp rax, 0
    jle .fim

    ; Escrever na saída padrão (STDOUT)
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [rsp + 128]
    syscall
    jmp .loop_principal

.fim:
    add rsp, 4112
    pop rbx
    pop rbp
    ret

pty_fechar:
    mov rax, SYS_CLOSE
    mov rdi, [fd_mestre]
    syscall
    mov rax, SYS_CLOSE
    mov rdi, [fd_escravo]
    syscall
    ret
