FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER_TLS_CERTDIR=

# Base utilities
RUN apt-get update && apt-get install -y ca-certificates curl gnupg iptables fuse-overlayfs pigz xz-utils unzip bash tini jq htop dnsutils make ripgrep fd-find \
  && rm -rf /var/lib/apt/lists/* && ln -s "$(command -v fdfind)" /usr/local/bin/fd

# --- Install Docker START -----------------------------------------------------
RUN apt-get update && install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  chmod a+r /etc/apt/keyrings/docker.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list && \
  apt-get update && apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
  rm -rf /var/lib/apt/lists/*

# Provide classic `docker-compose` shim for tooling expecting the legacy binary name
# NOTE: It's not 100% compatible: https://chatgpt.com/s/t_68b2c32724108191aa0c5ade45059ab7
RUN if ! command -v docker-compose >/dev/null 2>&1; then \
      echo '#!/usr/bin/env bash' > /usr/local/bin/docker-compose && \
      echo 'exec docker compose "$@"' >> /usr/local/bin/docker-compose && \
      chmod +x /usr/local/bin/docker-compose; \
    fi

VOLUME ["/var/lib/docker"]
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN : > /etc/curlrc
RUN mkdir -p /run /var/run && cat >/usr/local/bin/dind.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

configure_mitm_proxy() {
  local mitm_url="${ARTISAN_MITM_URL:-}"
  printf '%s\n' \
    "proxy = ${mitm_url}" \
    "insecure" \
    > /root/.curlrc
}

configure_mitm_proxy

mkdir -p /run /var/run /var/log
drv="${DOCKER_DRIVER:-overlay2}"
if ! grep -qw overlay /proc/filesystems; then
  drv="fuse-overlayfs"
fi
# TODO: generalize hardcoded IP
# Local registry mirror configuration:
REGISTRY_MIRROR="${REGISTRY_MIRROR:-http://129.69.217.154:5000}"
INSECURE_REGISTRY="${INSECURE_REGISTRY:-129.69.217.154:5000}"

start_dockerd() {
  dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver="${drv}" \
    --registry-mirror="${REGISTRY_MIRROR}" \
    --insecure-registry="${INSECURE_REGISTRY}" \
    > /var/log/dockerd.log 2>&1 &
  DOCKERD_PID=$!

  # Clean up daemon on exit
  _term() { kill -TERM "$DOCKERD_PID" 2>/dev/null || true; wait "$DOCKERD_PID" 2>/dev/null || true; }
  trap _term TERM INT EXIT

  # Wait until Docker is ready
  for i in {1..150}; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "dockerd failed to become ready" >&2
  exit 1
}
# If a command is provided, start dockerd in the background (so inner `docker` works), then exec the command.
if [ "$#" -gt 0 ]; then
  start_dockerd
  exec "$@"
fi

# No command: run dockerd in the foreground (classic dind behavior)
exec dockerd --host=unix:///var/run/docker.sock --storage-driver="${drv}"
EOF
RUN chmod +x /usr/local/bin/dind.sh

# Keep tini as PID 1 for proper signal handling/reaping
ENTRYPOINT ["tini","--","/usr/local/bin/dind.sh"]
# --- Install Docker END -----------------------------------------------------

# --- Install Artisan START -----------------------------------------------------
# Install uv (fast Python package/dependency manager)
RUN curl -fsSL https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Copy project files and dependencies (including local agents) and create venv
WORKDIR /opt/artisan
COPY pyproject.toml uv.lock README.md ./
COPY src ./src
COPY agents/mini-swe-agent ./agents/mini-swe-agent
COPY agents/SWE-agent ./agents/SWE-agent

# Sync dependencies into a dedicated venv and expose the CLI globally
RUN uv sync --frozen --no-dev && \
    ln -s /opt/artisan/.venv/bin/artisan /usr/local/bin/artisan

# Make the project root discoverable at runtime
ENV ARTISAN_DIR=/opt/artisan
# --- Install Artisan END -----------------------------------------------------

CMD ["bash"]
