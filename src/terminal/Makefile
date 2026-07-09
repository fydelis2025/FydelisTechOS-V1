CC = gcc
CXX = g++
AS = nasm
CFLAGS = -Wall -O2
CXXFLAGS = -Wall -O2 -std=c++17
ASFLAGS = -f elf64
# Corrigido: Adicionado -no-pie para permitir a linkagem do Assembly absoluto (.bss)
LDFLAGS = -no-pie -lutil -pthread

all: fydelterm

fydel_pty.o: fydel_pty.asm
	$(AS) $(ASFLAGS) -o $@ $<

fydel_check.o: fydel_check.c fydel_api.h
	$(CC) $(CFLAGS) -c -o $@ $<

fydel_gui.o: fydel_gui.cpp fydel_api.h
	$(CXX) $(CXXFLAGS) -c -o $@ $<

fydelterm: fydel_pty.o fydel_check.o fydel_gui.o
	$(CXX) $^ -o $@ $(LDFLAGS)

install: fydelterm
	# Cria os diretórios necessários dentro do sistema de arquivos da ISO
	install -d /usr/local/bin/
	install -d /usr/share/fydel/telas/
	
	# Instala o binário principal
	install -m 755 fydelterm /usr/local/bin/
	
	# Cria um arquivo de boas-vindas padrão caso ele não exista no chroot
	echo "--- FydelisTechOS Engine Ativa ---" > /usr/share/fydel/telas/tela_boas_vindas.txt
	chmod 644 /usr/share/fydel/telas/tela_boas_vindas.txt

clean:
	rm -f *.o fydelterm

.PHONY: all install clean
