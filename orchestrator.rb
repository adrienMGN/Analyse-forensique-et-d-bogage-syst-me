#!/usr/bin/env ruby
# encoding: utf-8

# librairies utilisées
require 'json'
require 'optparse' # gère les options en ligne de commande

# Codes de couleur ANSI pour l'affichage coloré
class Colors
  RED = "\033[31m"
  GREEN = "\033[32m"
  YELLOW = "\033[33m"
  BLUE = "\033[34m"
  MAGENTA = "\033[35m"
  CYAN = "\033[36m"
  WHITE = "\033[37m"
  BOLD = "\033[1m"
  RESET = "\033[0m"
end

# gestion des paramètres
options = {
  network: false,
  diag: false,
  pid: nil
}

OptionParser.new do |opt|
  opt.banner = "Usage: orchestrator.rb [options]"
  opt.separator ""
  opt.separator "Options:"
  
  opt.on("-n", "--network", "Audit réseau") do
    options[:network] = true
  end
  
  opt.on("-p PID", "--pid=PID", Integer, "Audit processus (spécifier le PID)") do |pid|
    options[:pid] = pid
  end
  
  opt.on("-d", "--diag", "Diagnostic système avancé") do
    options[:diag] = true
  end
  
  opt.on("-a", "--all", "Tous les audits (réseau + diagnostic)") do
    options[:network] = true
    options[:diag] = true
  end
  
  opt.on("-h", "--help", "Afficher cette aide") do
    puts opt
    puts "\nExemples:"
    puts "  orchestrator.rb -a              # Réseau + diagnostic"
    puts "  orchestrator.rb -n              # Uniquement réseau"
    puts "  orchestrator.rb -d              # Uniquement diagnostic"
    puts "  orchestrator.rb -p 1234 -n      # Réseau + processus 1234"
    exit
  end
end.parse!

# Si aucune option, afficher l'aide
if !options[:network] && !options[:pid] && !options[:diag]
  puts "#{Colors::YELLOW}Aucun audit sélectionné. Utilisez -h pour voir les options.#{Colors::RESET}"
  puts "\nExemple rapide: orchestrator.rb -a"
  exit 1
end

############ VARIABLES OPTIONS ############

PID = options[:pid]
ENABLE_NETWORK = options[:network]
ENABLE_PROCESS = !PID.nil?
ENABLE_DIAG = options[:diag]

######################## Execution distante ########################
# Configuration SSH pour exécuter les commandes sur la machine distante
HOST = ENV['TARGET_HOST'] || 'host.docker.internal' # adresse de la machine distante
USER = ENV['TARGET_USER'] || 'root' # utilisateur SSH 
KEY  = ENV['SSH_KEY_PATH'] || '/root/.ssh/id_rsa' # chemin vers la clé privée SSH dans le conteneur

# Fonction pour exécuter une commande distante via SSH
def run_remote(cmd, hide_errors = false)
  # -o options pour éviter les prompts d'authenticité de l'hôte
  stderr_redirect = hide_errors ? "2>/dev/null" : "2>&1"
  ssh_cmd = "ssh -o StrictHostKeyChecking=no -i #{KEY} #{USER}@#{HOST} \"#{cmd}\" #{stderr_redirect}"
  result = `#{ssh_cmd}`
  return result
end

# Fonction pour copier un fichier sur l'hôte distant via SCP
def copy_to_remote(local_path, remote_path)
  scp_cmd = "scp -q -o StrictHostKeyChecking=no -i #{KEY} #{local_path} #{USER}@#{HOST}:#{remote_path}"
  system(scp_cmd)
end


############ EXECUTION ############

### si pas lancer en root avertissement 
# uid = 0 pour root
if Process.uid != 0 then
  puts "#{Colors::RED}#{Colors::BOLD}###############################################################################{Colors::RESET}"
  puts "\n#{Colors::YELLOW}Attention: certains diagnostiques nécessitent les droits root pour un fonctionnement complet.#{Colors::RESET}\n"
  puts 
  puts "#{Colors::RED}#{Colors::BOLD}###############################################################################{Colors::RESET}"
end

############ ORCHESTRATION ############

puts "\n#{Colors::CYAN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}"
puts "#{Colors::CYAN}#{Colors::BOLD}                     DÉBUT DE L'AUDIT SYSTÈME COMPLET                          #{Colors::RESET}"
puts "#{Colors::CYAN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}\n"

# Préparation : créer le répertoire temporaire et copier les scripts
puts "\n#{Colors::MAGENTA}[Préparation] Copie des scripts sur l'hôte...#{Colors::RESET}"
STDOUT.flush
run_remote("mkdir -p /tmp/audit_scripts")
copy_to_remote("/app/audit_network.rb", "/tmp/audit_scripts/audit_network.rb") if ENABLE_NETWORK
copy_to_remote("/app/audit_proc.rb", "/tmp/audit_scripts/audit_proc.rb") if ENABLE_PROCESS
copy_to_remote("/app/diag_sys_avance.sh", "/tmp/audit_scripts/diag_sys_avance.sh") if ENABLE_DIAG
run_remote("chmod +x /tmp/audit_scripts/* 2>/dev/null")
puts "#{Colors::GREEN}✓ Scripts copiés#{Colors::RESET}"
STDOUT.flush

# 1. Audit réseau
if ENABLE_NETWORK
  puts "\n#{Colors::BLUE}#{Colors::BOLD}[Audit réseau]#{Colors::RESET}"
  puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
  STDOUT.flush
  network_output = run_remote("ruby /tmp/audit_scripts/audit_network.rb")
  puts network_output
  STDOUT.flush
end

# 2. Audit processus (si PID spécifié)
if ENABLE_PROCESS
  puts "\n#{Colors::BLUE}#{Colors::BOLD}[Audit processus - PID #{PID}]#{Colors::RESET}"
  puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
  proc_output = run_remote("ruby /tmp/audit_scripts/audit_proc.rb #{PID}")
  puts proc_output
end

# 3. Diagnostic système avancé
if ENABLE_DIAG
  puts "\n#{Colors::BLUE}#{Colors::BOLD}[Diagnostic système avancé]#{Colors::RESET}"
  puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
  diag_output = run_remote("bash /tmp/audit_scripts/diag_sys_avance.sh")
  puts diag_output
end

puts "\n#{Colors::GREEN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}"
puts "#{Colors::GREEN}#{Colors::BOLD}                     AUDIT SYSTÈME TERMINÉ                                      #{Colors::RESET}"
puts "#{Colors::GREEN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}\n"
run_remote("mkdir -p /tmp/audit_scripts")
copy_to_remote("/app/audit_network.rb", "/tmp/audit_scripts/audit_network.rb")
copy_to_remote("/app/audit_proc.rb", "/tmp/audit_scripts/audit_proc.rb")
copy_to_remote("/app/diag_sys_avance.sh", "/tmp/audit_scripts/diag_sys_avance.sh")
run_remote("chmod +x /tmp/audit_scripts/*.rb /tmp/audit_scripts/*.sh")
puts "#{Colors::GREEN}✓ Scripts copiés avec succès#{Colors::RESET}"
STDOUT.flush

# 1. Audit réseau
puts "\n#{Colors::BLUE}#{Colors::BOLD}[1/3] Lancement de l'audit réseau...#{Colors::RESET}"
puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
STDOUT.flush
network_output = run_remote("ruby /tmp/audit_scripts/audit_network.rb")
puts network_output
STDOUT.flush

# 2. Audit processus (si PID spécifié)
if PID
  puts "\n#{Colors::BLUE}#{Colors::BOLD}[2/3] Lancement de l'audit processus pour PID #{PID}...#{Colors::RESET}"
  puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
  proc_output = run_remote("ruby /tmp/audit_scripts/audit_proc.rb #{PID}")
  puts proc_output
  # Récupérer le fichier de rapport si créé
  report_file = "process_report_#{PID}.log"
  report_content = run_remote("cat #{report_file} 2>/dev/null")
  if !report_content.empty?
    puts "\n#{Colors::GREEN}Contenu du rapport détaillé:#{Colors::RESET}"
    puts report_content
  end
else
  puts "\n#{Colors::YELLOW}#{Colors::BOLD}[2/3] Audit processus ignoré (aucun PID spécifié avec -p)#{Colors::RESET}"
end

# 3. Diagnostic système avancé
puts "\n#{Colors::BLUE}#{Colors::BOLD}[3/3] Lancement du diagnostic système avancé...#{Colors::RESET}"
puts "#{Colors::CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{Colors::RESET}"
diag_output = run_remote("bash /tmp/audit_scripts/diag_sys_avance.sh")
puts diag_output

puts "\n#{Colors::GREEN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}"
puts "#{Colors::GREEN}#{Colors::BOLD}                     AUDIT SYSTÈME TERMINÉ AVEC SUCCÈS                          #{Colors::RESET}"
puts "#{Colors::GREEN}#{Colors::BOLD}════════════════════════════════════════════════════════════════════════════════#{Colors::RESET}\n"

