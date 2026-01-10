#!/bin/bash
# Local script to run Docker-based installation tests
# Usage: ./scripts/run-docker-tests.sh [base_image]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_ROOT/tests"

BASE_IMAGE="${1:-ghcr.io/prefix-dev/pixi:latest}"
TEST_TAG="blooop-test:local"

echo "========================================"
echo "blooop-feedstock Docker Installation Tests"
echo "========================================"
echo ""
echo "Base image: $BASE_IMAGE"
echo "Project root: $PROJECT_ROOT"
echo ""

# Build the test image
echo "Building test image..."
docker build \
    --build-arg "BASE_IMAGE=$BASE_IMAGE" \
    -t "$TEST_TAG" \
    "$TESTS_DIR"

echo ""
echo "Running tests..."
echo ""

# Run the tests
docker run --rm "$TEST_TAG"

# Cleanup
echo ""
echo "Cleaning up..."
docker rmi "$TEST_TAG" 2>/dev/null || true

echo ""
echo "Done!"
