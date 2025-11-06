# Based on official Anthropic Claude Code devcontainer
FROM node:20

ARG TZ
ENV TZ="$TZ"
ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    man-db \
    unzip \
    gnupg2 \
    gh \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    jq \
    nano \
    vim \
    curl \
    cron \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
    chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
    chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

# Install git-delta for better diffs (optional, skip if download fails)
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    (wget --no-check-certificate "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" || echo "git-delta installation skipped")

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh
ENV SHELL=/bin/zsh

# Set the default editor
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -x

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install Workshop for persistent memory
RUN npm install -g @zachswift615/workshop

# Install MCP Servers for JADE
# Slack MCP Server (maintained by Zencoder)
RUN npm install -g @zencoderai/slack-mcp-server

# Download GitHub MCP Server binary (official GitHub, written in Go)
USER root
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        GITHUB_MCP_ARCH="linux_amd64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        GITHUB_MCP_ARCH="linux_arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    (curl -k -L "https://github.com/github/github-mcp-server/releases/download/v0.20.1/github-mcp-server_${GITHUB_MCP_ARCH}" \
        -o /usr/local/bin/github-mcp-server && \
    chmod +x /usr/local/bin/github-mcp-server || echo "github-mcp-server installation skipped")

# Copy entrypoint and cron scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY jade-cron.sh /usr/local/bin/jade-cron.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/jade-cron.sh

# Copy CLAUDE.md to user's .claude directory
COPY CLAUDE.md /home/node/.claude/CLAUDE.md
RUN chown node:node /home/node/.claude/CLAUDE.md

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
