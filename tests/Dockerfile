# Test container for blooop-feedstock package installation verification
# Uses pixi-docker as base image

ARG BASE_IMAGE=ghcr.io/prefix-dev/pixi:latest
FROM ${BASE_IMAGE}

# Install curl (needed by claude-code shim to download binary)
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /test

# Copy test script
COPY test-install.sh /test/test-install.sh
RUN chmod +x /test/test-install.sh

# Run tests
ENTRYPOINT ["/test/test-install.sh"]
