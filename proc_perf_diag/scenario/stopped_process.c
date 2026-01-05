#include <stdio.h>
#include <signal.h>
#include <unistd.h>

// Ce programme simule un processus dans l'état T (Stopped)
// Il s'arrête en attendant un signal SIGCONT

int main() {
    printf("Processus démarré (PID: %d)\n", getpid());
    printf("Le processus va s'arrêter (état T - Stopped)\n");
    printf("Pour le réactiver: kill -CONT %d\n", getpid());
    printf("Pour le terminer: kill -TERM %d\n\n", getpid());
    
    fflush(stdout);
    
    // Attendre un peu avant de s'arrêter
    sleep(1);
    
    // S'envoyer SIGSTOP pour passer en état T
    printf("Envoi de SIGSTOP...\n");
    fflush(stdout);
    
    raise(SIGSTOP);
    
    // Ce code ne sera exécuté qu'après réception de SIGCONT
    printf("\n[Processus réactivé avec SIGCONT]\n");
    printf("Le processus va maintenant tourner indéfiniment.\n");
    printf("Utilisez Ctrl+Z pour l'arrêter à nouveau, ou Ctrl+C pour le terminer.\n");
    
    // Boucle infinie après réactivation
    while (1) {
        sleep(10);
    }
    
    return 0;
}
