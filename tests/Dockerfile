# Test container for blooop-feedstock package installation verification
# Uses pixi-docker as base image

ARG BASE_IMAGE=ghcr.io/prefix-dev/pixi:latest
FROM ${BASE_IMAGE}

# Set up working directory
WORKDIR /test

# Copy test script
COPY test-install.sh /test/test-install.sh
RUN chmod +x /test/test-install.sh

# Run tests
ENTRYPOINT ["/test/test-install.sh"]
