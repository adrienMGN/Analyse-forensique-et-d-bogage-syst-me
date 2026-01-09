FROM debian:bookworm

LABEL description="Container d'orchestration des scripts d'audit via SSH"
ENV DEBIAN_FRONTEND noninteractive

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    openssh-client \
    procps \
    ruby \
    nginx \
    ruby \
    iproute2 \
    iptables \
    net-tools \
    dnsutils \
    iputils-ping \
    traceroute \
    mtr-tiny \
    nmap \
    tcpdump \
    procps \
    curl \
    vim \
    netcat-traditional \
    sysstat \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copie du script d'orchestration d'audit
COPY orchestrator.rb /app/orchestrator.rb

# copy des scripts d'audit (network, diag_sys avancé.sh, audit_proc.rd)
COPY audit_network/audit_network.rb /app/audit_network.rb
COPY ./diag_sys_avance.sh /app/diag_sys_avance.sh
COPY ./proc_perf_diag/audit_proc/audit_proc.rb /app/audit_proc.rb



# droit exec sur les scripts
RUN chmod +x /app/orchestrator.rb
RUN chmod +x /app/diag_sys_avance.sh
RUN chmod +x /app/audit_network.rb
RUN chmod +x /app/audit_proc.rb

# Configuration SSH (dir, droits, StrictHostKeyChecking pour éviter les prompts, droit de config)
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    touch /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa && \
    echo "StrictHostKeyChecking no" > /root/.ssh/config && \
    chmod 600 /root/.ssh/config


