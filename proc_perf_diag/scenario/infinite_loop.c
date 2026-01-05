#include <stdio.h>

// boucle infinie pour tester le diagnostic de performance du processus (etat D Z etc)
int main() {
    printf("Démarrage de la boucle infinie (100%% CPU)...\n");
    fflush(stdout); // flush pour s'assurer que le message est affiché
    
    // volatile pour éviter l'optimisation du compilateur
    volatile int counter = 0;
    while (1) {
        // Infinite loop - consomme du CPU
        counter++;
    }
    return 0;
}