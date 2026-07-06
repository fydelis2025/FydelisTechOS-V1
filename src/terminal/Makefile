CC = gcc
CXX = g++
AS = nasm
CFLAGS = -Wall -O2
CXXFLAGS = -Wall -O2 -std=c++17
ASFLAGS = -f elf64
LDFLAGS = -lutil -pthread

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
	install -m 755 fydelterm /usr/local/bin/

clean:
	rm -f *.o fydelterm

.PHONY: all install clean