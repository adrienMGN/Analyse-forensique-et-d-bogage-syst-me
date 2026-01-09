FROM debian:12

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

# Installation des paquets requis pour l'investigation et systemd
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    openssh-server \
    iproute2 \
    sudo \
    auditd \
    rsyslog \
    vim \
    net-tools \
    procps \
    python3 \
    stress \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuration SSH
RUN mkdir /var/run/sshd
RUN echo 'root:toor' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Script de préparation (utilisateurs, fichiers logs factices)
COPY setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

WORKDIR /app

# Systemd cleanup
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/lib/systemd/systemd"]