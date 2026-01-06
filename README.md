# Analyse forensique et débogage système

## Analyse de processus et performances

---

1)
Localisation des ressources :

Scénarios de test : accessibles dans le dossier `proc_perf_diag/scenario`.

Guide méthodologique : le fichier `proc_perf_diag/Methodology.md` décrit les étapes d'implémentation et les indicateurs d'observation.

2) Analyse opérationnelle des scénarios de test
   2)1) La boucle infinie
   
Avec la commande ps aux (affichage du pourcentage de l'utilisation du cpu et de l'état) :

```bash
cd proc_perf_diag/scenario/
make
./infinite_loop
ps aux | awk 'NR==1 || /infinite_loop/'
```
En exécution : Le processus est visible et marqué du statut R (Running) et le cpu est à 100%.

À l'arrêt : Le processus disparaît de la table des processus système.
