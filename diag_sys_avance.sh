#!/bin/bash

commandes=(
  "vmstat"
  "iostat"
  "mpstat"
  "sudo iotop"
  "sar -A"
  "sudo dmesg"
  "systemd-analyze"
)

echo "----- Diagnostic système avancé interactif -----"
echo

for cmd in "${commandes[@]}"; do
  echo "--------------------------------------"
  $cmd
  echo "--------------------------------------"
done

echo
echo "----- Diagnostic terminé -----"
