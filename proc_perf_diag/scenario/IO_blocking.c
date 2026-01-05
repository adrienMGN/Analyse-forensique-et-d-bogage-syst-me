// Ce programme simule un processus en attente d'entrée utilisateur (état S - Sleeping)
// Note: Ce programme sera en état S (sleeping interruptible), pas D
// Pour l'état D (disk sleep), voir disk_sleep.c
#include <stdio.h>
#include <unistd.h>

int main() {
    char buffer[1024];
    printf("Programme en attente d'entrée stdin (état S - Sleeping)...\n");
    printf("Tapez du texte et appuyez sur Entrée. Ctrl+D pour terminer.\n");
    
    // Bloquer en lisant stdin - met le processus en état S
    while (fgets(buffer, sizeof(buffer), stdin) != NULL) {
        printf("Reçu: %s", buffer); // Echo de l'entrée reçue
    }
    
    return 0;
}