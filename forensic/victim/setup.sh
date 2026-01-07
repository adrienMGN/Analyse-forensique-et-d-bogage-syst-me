#!/bin/bash
# Création d'un utilisateur standard
useradd -m -s /bin/bash employe
echo "employe:123456" | chpasswd
usermod -aG sudo employe

# Démarrage des services
systemctl enable ssh
systemctl enable nginx
systemctl enable rsyslog