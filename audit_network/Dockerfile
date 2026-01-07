FROM debian:12

RUN apt-get update && apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY audit_network.rb /app/audit_network.rb
COPY scenario.rb /app/scenario.rb

# Permissions
RUN chmod +x /app/scenario.rb
RUN echo "<h1>Lab test DACS</h1>" > /var/www/html/index.html

CMD service nginx start && tail -f /dev/null