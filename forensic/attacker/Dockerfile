FROM kalilinux/kali-rolling

RUN apt-get update && apt-get install -y \
    iproute2 \
    openssh-client \
    hydra \
    nmap \
    netcat-traditional \
    sshpass \
    iputils-ping \
    dnsutils \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copie de la wordlist pour les attaques par dictionnaire
COPY wordlist.txt /root/wordlist.txt

# Boucle infinie pour garder le conteneur actif
CMD ["tail", "-f", "/dev/null"]