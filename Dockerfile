# Dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites including OpenSSL for TLS
RUN apt-get update && apt-get install -y \
    fortunes \
    cowsay \
    netcat-openbsd \
    openssl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Add /usr/games to PATH
ENV PATH="/usr/games:${PATH}"

WORKDIR /app

# Copy project files
COPY wisecow.sh /app/

# Copy TLS certificates (optional - for testing)
COPY tls/ /app/tls/

# Make the script executable
RUN chmod +x /app/wisecow.sh

# Create non-root user for security
RUN useradd -m -u 1000 wisecow && chown -R wisecow:wisecow /app
USER wisecow

EXPOSE 4499

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD nc -z localhost 4499 || exit 1

CMD ["/app/wisecow.sh"]
