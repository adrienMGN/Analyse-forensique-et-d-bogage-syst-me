#!/bin/bash

commandes=(
  "vmstat"
  "iostat"
)

echo "----- Diagnostic système avancé interactif -----"
echo

for cmd in "${commandes[@]}"; do
  echo "--------------------------------------"
  echo "Commande : $cmd"
  read -rp "Lancer le diagnostique ? [Y/N] : " choice

  if [[ "$choice" =~ ^[yY]$ ]]; then
    echo
    echo "--------------------------------------"
    $cmd
    echo
  else
    echo "Commande ignorée."
  fi
done

echo
echo "----- Diagnostic terminé -----"
