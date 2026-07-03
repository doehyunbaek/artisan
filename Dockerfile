FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/doehyunbaek/artisan" \
      org.opencontainers.image.description="Artifact evaluation image for Artisan" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    UV_PROJECT_ENVIRONMENT=/opt/artisan-venv \
    UV_LINK_MODE=copy \
    PATH="/root/.local/bin:/opt/artisan-venv/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    docker.io \
    git \
    make \
    poppler-utils \
    python3 \
    python3-pip \
    python3-pygments \
    python3-venv \
    texlive-bibtex-extra \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-latex-recommended \
    texlive-plain-generic \
    texlive-publishers \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /artifact
COPY . /artifact

RUN git submodule update --init --recursive || true
RUN uv sync && uv pip install -e .

CMD ["/opt/artisan-venv/bin/python", "/artifact/data/reproduce.py"]
