CC = gcc
CFLAGS = -Wall -Wextra -O2

# Liste des programmes à compiler (couvre tous les états: R, S, D, Z, T)
PROGRAMS = infinite_loop IO_blocking memory_leak zombie_process stopped_process disk_sleep

all: $(PROGRAMS)

# Règles de compilation standard
infinite_loop: infinite_loop.c
	$(CC) $(CFLAGS) -o $@ $<

IO_blocking: IO_blocking.c
	$(CC) $(CFLAGS) -o $@ $<

memory_leak: memory_leak.c
	$(CC)  -o $@ $<

zombie_process: zombie_process.c
	$(CC) $(CFLAGS) -o $@ $<

stopped_process: stopped_process.c
	$(CC) $(CFLAGS) -o $@ $<

disk_sleep: disk_sleep.c
	$(CC) $(CFLAGS) -o $@ $<

# Nettoyer les exécutables
clean:
	rm -f $(PROGRAMS)

# Nettoyer et recompiler
rebuild: clean all

.PHONY: all clean rebuild
