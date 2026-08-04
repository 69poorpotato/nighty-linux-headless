FROM ubuntu:24.04

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive \
    PUID=1000 \
    PGID=1000

# Install base dependencies required by install.sh and run.sh
# Ubuntu 24.04 provides Wine 9.0 by default, which install.sh will detect as <10
# and it will automatically fall back to downloading static Wine 10 on first run.
RUN apt-get update && apt-get install -y \
    curl wget tar xz-utils gnupg sudo \
    python3 xvfb \
    wine64 wine \
    && rm -rf /var/lib/apt/lists/*

# Create a dedicated user for running Nighty
# Ubuntu 24.04 pre-creates an 'ubuntu' user with UID/GID 1000. We remove it so we can use 1000.
# Passwordless sudo is required because install.sh modifies /etc/hosts for RP-fetch blackholing
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd -g ${PGID} nighty && \
    useradd -u ${PUID} -g ${PGID} -m -s /bin/bash nighty && \
    echo "nighty ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nighty

# Setup directories
WORKDIR /app
COPY . /app

RUN mkdir -p /data/nighty && \
    chown -R nighty:nighty /app /data

# Default environment variables
ENV WEBUI_HOST=0.0.0.0 \
    BRIDGE_HOST=0.0.0.0

USER nighty

# Persist data outside the container
VOLUME ["/data"]

EXPOSE 8088

CMD ["bash", "scripts/docker-entrypoint.sh"]
