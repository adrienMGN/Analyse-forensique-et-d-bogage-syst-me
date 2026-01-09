#!/usr/bin/env bash
# filepath: /home/sinje/Projet-audit-et-d-ploiement/monitoring-infrastructure/agent/deploy.sh

set -e

echo "=== Configuration de l'audit système Docker ==="

# 1. Vérifier que SSH est installé sur l'hôte
if ! systemctl is-active --quiet ssh; then
    echo "Installation du serveur SSH..."
    sudo apt-get update
    sudo apt-get install -y openssh-server nethogs
    sudo systemctl enable ssh
    sudo systemctl start ssh
fi



# 2. Créer le répertoire de sortie AVANT de générer les clés
mkdir -p output
mkdir -p ssh-keys

# 3. Générer les clés SSH si elles n'existent pas
if [ ! -f ./ssh-keys/id_rsa ]; then
    echo "Génération des clés SSH..."
    ssh-keygen -t rsa -b 4096 -f ./ssh-keys/id_rsa -N "" -C "audit-container"
    echo "✓ Clés SSH générées"
else
    echo "✓ Clés SSH déjà présentes"
fi

# Vérifier que les clés ont bien été créées
if [ ! -f ./ssh-keys/id_rsa ] || [ ! -f ./ssh-keys/id_rsa.pub ]; then
    echo "✗ ERREUR: Les clés SSH n'ont pas été créées correctement"
    exit 1
fi

echo "Contenu de la clé publique:"
cat ./ssh-keys/id_rsa.pub

# 4. Ajouter la clé publique aux autorisations root
echo "Ajout de la clé publique aux autorisations..."
sudo mkdir -p /root/.ssh

# Vérifier si la clé est déjà présente pour éviter les doublons
KEY_CONTENT=$(cat ./ssh-keys/id_rsa.pub)
if sudo grep -qF "$KEY_CONTENT" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "✓ Clé déjà présente dans authorized_keys"
else
    sudo cat ./ssh-keys/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys > /dev/null
    echo "✓ Clé ajoutée à authorized_keys"
fi

sudo chmod 600 /root/.ssh/authorized_keys
sudo chmod 700 /root/.ssh

# 5. Afficher les informations de configuration
echo ""
echo "Configuration SSH:"
echo "  - Clé privée: ./ssh-keys/id_rsa"
echo "  - Clé publique: ./ssh-keys/id_rsa.pub"
echo "  - authorized_keys: /root/.ssh/authorized_keys"

# 6. Tester la connexion SSH depuis l'hôte
echo ""
echo "Test de connexion SSH..."
if ssh -i ./ssh-keys/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@localhost "echo 'SSH OK'" 2>/dev/null; then
    echo " Connexion SSH fonctionnelle"
else
    echo " Attention: Test SSH échoué (normal si root login est désactivé)"
fi

# 7. Build et lancement du conteneur
echo ""
echo "Construction de l'image Docker..."
docker compose build

echo ""
echo "Démarrage des conteneurs..."
docker compose up -d

# 8. Vérifications
echo ""
echo "========================================="
echo "✓ Déploiement terminé"
echo "========================================="
docker exec -it audit_orchestrator_container bash