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
options = {}

OptionParser.new do |opt|
  opt.banner = "Usage: audit.rb [options]"
  opt.separator ""
  opt.separator "Options:"
  
  # option PID pour audit_proc.rb
  opt.on("-pPID", "--pid=PID", Integer, "PID du processus à auditer avec audit_proc.rb") do |pid|
    options[:pid] = pid
  end
  # option 
end.parse!

############ VARIABLES OPTIONS ############

PID = options[:pid] || nil # PID du processus à auditer (défaut 1 init/systemd)

######################## Execution distante ########################
# Configuration SSH pour exécuter les commandes sur la machine distante
HOST = ENV['TARGET_HOST'] || 'host.docker.internal' # adresse de la machine distante
USER = ENV['TARGET_USER'] || 'root' # utilisateur SSH 
KEY  = ENV['SSH_KEY_PATH'] || '/root/.ssh/id_rsa' # chemin vers la clé privée SSH dans le conteneur

# Fonction pour exécuter une commande distante via SSH
def run_remote(cmd)
  # -o options pour éviter les prompts d'authenticité de l'hôte
  ssh_cmd = "ssh -o StrictHostKeyChecking=no -i #{KEY} #{USER}@#{HOST} \"#{cmd}\" 2>/dev/null"
  result = `#{ssh_cmd}`
  return result.strip
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

run_remote(system (/app/audit_network.rb))

if PID then
  run_remote(system (/app/audit_proc.rb PID))
else
  puts "#{Colors::YELLOW}Aucun PID spécifié pour audit_proc.rb.#{Colors::RESET}"
end

run_remote(system (/app/diag_sys_avance.sh))

