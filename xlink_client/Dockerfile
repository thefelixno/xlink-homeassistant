ARG BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN \
    apk add --no-cache \
        ca-certificates \
        curl \
        socat \
        iptables \
        libqrencode-tools \
        openresolv \
    && ln -sf /sbin/xtables-nft-multi /sbin/ip6tables \
    && ln -sf /sbin/xtables-nft-multi /sbin/iptables

# Download and install Tailscale static binary
RUN \
    if [ "${BUILD_ARCH}" = "aarch64" ]; then \
        TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_1.80.2-linux-arm64.tgz"; \
    else \
        TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_1.80.2-linux-amd64.tgz"; \
    fi && \
    curl -fsSL "$TAILSCALE_URL" -o /tmp/tailscale.tgz && \
    mkdir -p /tmp/tailscale-extract && \
    tar xzf /tmp/tailscale.tgz -C /tmp/tailscale-extract && \
    cp /tmp/tailscale-extract/tailscale-* /usr/bin/tailscale && \
    chmod +x /usr/bin/tailscale && \
    rm -rf /tmp/tailscale.tgz /tmp/tailscale-extract

# Copy root filesystem
COPY rootfs /

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Felix Nölte <mail@felixnoelte.de>"
