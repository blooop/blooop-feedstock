# Test container for blooop-feedstock package installation verification
# Uses pixi-docker as base image

ARG BASE_IMAGE=ghcr.io/prefix-dev/pixi:latest
FROM ${BASE_IMAGE}

# Install curl (needed by claude-shim to download binary)
# Retry apt-get to tolerate transient mirror/network failures in CI
RUN set -eux; \
    ok=0; \
    for i in 1 2 3 4 5; do \
        if apt-get update && apt-get install -y --no-install-recommends curl ca-certificates; then \
            ok=1; break; \
        fi; \
        echo "apt-get attempt $i failed, retrying in 10s..."; \
        sleep 10; \
    done; \
    [ "$ok" = "1" ] || { echo "apt-get failed after 5 attempts"; exit 1; }; \
    rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /test

# Copy test script
COPY test-install.sh /test/test-install.sh
RUN chmod +x /test/test-install.sh

# Run tests
ENTRYPOINT ["/test/test-install.sh"]
