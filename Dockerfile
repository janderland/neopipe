# Dockerfile for linting and testing pipe.nvim
FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    git \
    neovim \
    lua5.1 \
    luarocks \
    liblua5.1-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install luacheck via luarocks
RUN luarocks install luacheck

# Install lua-language-server (detect architecture)
ARG TARGETARCH
RUN mkdir -p /opt/lua-language-server && \
    cd /opt/lua-language-server && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        ARCH="linux-arm64"; \
    else \
        ARCH="linux-x64"; \
    fi && \
    curl -L -o lls.tar.gz "https://github.com/LuaLS/lua-language-server/releases/download/3.10.6/lua-language-server-3.10.6-${ARCH}.tar.gz" && \
    tar -xzf lls.tar.gz && \
    rm lls.tar.gz && \
    ln -s /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server

# Download Neovim Lua type annotations for lua-language-server
RUN mkdir -p /opt/lua-language-server/meta/3rd && \
    cd /opt/lua-language-server/meta/3rd && \
    curl -L -o neodev.tar.gz "https://github.com/folke/neodev.nvim/archive/refs/tags/v3.0.0.tar.gz" && \
    tar -xzf neodev.tar.gz && \
    mv neodev.nvim-3.0.0/types/nightly nvim && \
    rm -rf neodev.nvim-3.0.0 neodev.tar.gz

WORKDIR /workspace

# Copy plugin and config files
COPY lua/ ./lua/
COPY plugin/ ./plugin/
COPY .luarc.json .luacheckrc ./

# Default command runs luacheck
CMD ["luacheck", "lua/"]
