FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gnupg \
        git && \
    # Add the official source of Node.js 20 (for building WhatsApp bridge)
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    # Install Node.js (you can lock the specific version number here, for example, node.js =20.18.0-1nodesource1)
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    # Clear out the build tools and caches that are no longer needed
    apt-get purge -y gnupg curl && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
RUN mkdir -p nanobot bridge && touch nanobot/__init__.py && \
    uv pip install --system --no-cache . && \
    rm -rf nanobot bridge

COPY nanobot/ nanobot/
COPY bridge/ bridge/
RUN uv pip install --system --no-cache .

WORKDIR /app/bridge
RUN npm install && npm run build

# ---------------------------------------------
# Phase Two: Build the final running image (also a slim image based on uv)
# ---------------------------------------------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Minimum system dependencies required during installation and runtime (for example, tini for signal processing)
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

# Copy the installed Python packages and application files from the build phase
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /app /app

WORKDIR /app

# ---------- Core security reinforcement section ----------
# 1. Create a non-root user (using a fixed UID/GID of 1000)
RUN groupadd -g 1000 nanobot && \
    useradd -m -u 1000 -g nanobot -s /bin/bash nanobot

# 2. Set the correct ownership and strict permissions
RUN mkdir -p /home/nanobot/.nanobot && \
    chown -R nanobot:nanobot /app /home/nanobot/.nanobot && \
    chmod 750 /app && \
    chmod 750 /home/nanobot/.nanobot

# 3. Switch to a non-root user
USER nanobot

# 4. Set environment variables to ensure that the program can find the configuration
ENV HOME=/home/nanobot
ENV NANOBOT_CONFIG_DIR=/home/nanobot/.nanobot
ENV PATH="/home/nanobot/.local/bin:${PATH}"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
# ------------------------------------

EXPOSE 18790

ENTRYPOINT ["/usr/bin/tini", "--", "nanobot"]

CMD ["status"]
