#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

// Créer une fuite de mémoire pour tester le diagnostic de performance du processus
int main() {
    printf("Début de la fuite mémoire...\n");
    int count = 0;
    
    while (1) {
        malloc(1024 * 1024); // Allouer 1 MB sans le libérer
        count++;
        
        if (count % 100 == 0) {
            printf("Fuite: %d MB alloués\n", count);
        }
        
        usleep(100000); // Pause de 100ms pour rendre observable
    }
    return 0;
}