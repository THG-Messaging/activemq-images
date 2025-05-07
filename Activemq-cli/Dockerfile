FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    git \
    curl \
    openssh \
    jq \
    coreutils \
    unzip \
    gnupg \
    xmlstarlet

COPY gh_2.49.0_linux_amd64.tar.gz ./gh.tar.gz

# Install GitHub CLI
RUN tar -xzf gh.tar.gz && \
    mv gh_2.49.0_linux_amd64/bin/gh /usr/local/bin/ && \
    chmod +x /usr/local/bin/gh && \
    rm -rf gh.tar.gz gh_2.49.0_linux_amd64 \
    mkdir \bindings

# Copy scripts and config
COPY entrypoint.sh /entrypoint.sh
COPY config.env /config/config.env
COPY github_token.sec /config/github_token.sec

# Set permissions
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
