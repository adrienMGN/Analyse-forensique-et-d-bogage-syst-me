Ce script réalise un diagnostic rapide de la posture réseau et de la configuration d'une machine Linux. Voici les justifications des choix techniques et logiques implémentés :

    Utilisation des commandes modernes (ss, ip) : Le script privilégie ss et ip au détriment des outils dépréciés (netstat, ifconfig) pour assurer la rapidité d'exécution et la compatibilité avec les distributions récentes.

    Zéro dépendance externe : Utilisation de la bibliothèque standard Ruby uniquement. Cela permet d'exécuter le script sur n'importe quel serveur disposant de Ruby sans avoir besoin de bundle install ou de droits d'accès à Internet.

    Filtrage des services exposés (0.0.0.0, ::) : L'alerte se déclenche spécifiquement sur les interfaces d'écoute universelles. Les services écoutant uniquement sur localhost sont considérés comme sûrs.

    Liste blanche d'IP privées (RFC 1918) : Les connexions vers les réseaux locaux (10.x, 192.168.x, etc.) sont ignorées lors de l'analyse des "connexions suspectes" pour se concentrer uniquement sur le trafic sortant vers Internet.

    Ports hauts (> 40000) : Le ciblage des ports de destination élevés vers des IP publiques sert à identifier les comportements atypiques (souvent liés à des malwares ou du C2), bien que cela puisse inclure du trafic P2P légitime.

    Vérification de la cohérence "Couche 2/3" : La détection d'interfaces UP sans adresse IP permet d'isoler rapidement les problèmes de DHCP ou de configuration manuelle avant d'analyser la sécurité.

    Détection des privilèges pour le Firewall : La vérification iptables est conditionnée à l'UID 0 (root), évitant les erreurs d'exécution inutiles si le script est lancé par un utilisateur standard.
