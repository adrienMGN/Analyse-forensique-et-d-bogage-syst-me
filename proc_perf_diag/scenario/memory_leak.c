#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    printf("Début de la fuite mémoire massive (256 MB par étape)...\n");
    int count = 0;
    
    // 256 * 1024 * 1024 octets = 256 MB = 0.25 GB
    size_t taille_fuite = 256 * 1024 * 1024; 

    while (1) {
        // Allouer 256 MB sans le libérer
        void *ptr = malloc(taille_fuite); 
        count++;
        // on force la mémoire à devenir résidente
	if (ptr != NULL) {
		memset(ptr, 0, 256 * 1024 * 1024); // on écrit des zéros partout
        }

        // On affiche la mémoire totale théoriquement "perdue"
        // count * 256 MB
        printf("Itération %d : ~%.2f GB alloués au total\n", count, (count * 256.0) / 1024.0);
        
        usleep(500000); // 100ms
    }
    return 0;
}
