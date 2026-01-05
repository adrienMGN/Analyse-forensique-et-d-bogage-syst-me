#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

// Crée des processus zombies pour tester la détection
int main() {
    printf("Création de 5 processus zombies...\n");
    
    for (int i = 0; i < 5; i++) {
        pid_t pid = fork();
        
        if (pid < 0) {
            perror("fork");
            exit(1);
        }
        
        if (pid == 0) {
            // Processus enfant - termine immédiatement
            printf("Enfant %d (PID: %d) se termine\n", i+1, getpid());
            exit(0);
        }
        // Parent ne fait pas wait() -> les enfants deviennent zombies
    }
    
    printf("Parent (PID: %d) reste actif. Les enfants sont maintenant zombies.\n", getpid());
    printf("Vérifiez avec: ps aux | grep Z ou ps -l\n");
    
    // Parent reste actif pour maintenir les zombies
    while (1) {
        sleep(10);
    }
    
    return 0;
}
