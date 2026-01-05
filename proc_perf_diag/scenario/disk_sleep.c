#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/vfs.h>
#include <string.h>

// Ce programme tente de forcer l'état D (Disk sleep - uninterruptible sleep)
// L'état D est difficile à simuler car il nécessite une vraie opération I/O bloquante
// Ce programme utilise sync() et des opérations de fichier qui peuvent bloquer

int main() {
    printf("Tentative de mise en état D (Disk sleep - uninterruptible sleep)\n");
    printf("PID: %d\n", getpid());
    printf("Note: L'état D est difficile à atteindre sans matériel lent ou NFS non-responsive\n\n");
    
    // Créer un fichier de test
    const char* filename = "/tmp/disk_sleep_test.dat";
    printf("Création d'un fichier de test: %s\n", filename);
    
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC | O_SYNC | O_DIRECT, 0644);
    if (fd < 0) {
        // Si O_DIRECT échoue, réessayer sans
        fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC | O_SYNC, 0644);
    }
    
    if (fd < 0) {
        perror("open");
        exit(1);
    }
    
    printf("Fichier ouvert. Début des écritures synchrones...\n");
    printf("Vérifiez l'état avec: ps -l $(pgrep disk_sleep) ou watch -n 0.1 'ps -eo pid,state,comm | grep disk_sleep'\n\n");
    
    // Buffer de 1 MB
    char* buffer = (char*)malloc(1024 * 1024);
    if (!buffer) {
        perror("malloc");
        close(fd);
        exit(1);
    }
    
    memset(buffer, 'D', 1024 * 1024);
    
    int iteration = 0;
    while (1) {
        // Écriture synchrone (O_SYNC force le flush sur disque)
        ssize_t written = write(fd, buffer, 1024 * 1024);
        if (written < 0) {
            perror("write");
            break;
        }
        
        // Force un sync complet du système de fichiers
        // sync() peut mettre le processus en état D pendant l'opération
        sync();
        
        // fsync() sur le fichier - peut aussi causer l'état D
        fsync(fd);
        
        iteration++;
        if (iteration % 10 == 0) {
            printf("Itération %d - Écritures synchrones en cours...\n", iteration);
        }
        
        // Petite pause pour ne pas trop charger le système
        usleep(100000); // 100ms
    }
    
    free(buffer);
    close(fd);
    unlink(filename);
    
    return 0;
}
