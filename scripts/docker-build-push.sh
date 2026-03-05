#!/bin/bash
# Build ZeroClaw Docker images for multiple architectures, push to registry, and optionally pull
#
# Usage:
#   ./scripts/docker-build-push.sh [jdc|local]
#
# Arguments:
#   jdc     Build, push, and pull on jdc host. Restart container.
#   local   Build, push, and pull locally.
#   (none)  Build and push only.

set -euo pipefail

# Hardcoded configuration
TAG="latest"
REGISTRY="registry.cn-hangzhou.aliyuncs.com/cwpypy"
IMAGE_NAME="zeroclaw-with-lark"

# Target from argument (default: jdc)
PULL_TARGET="${1:-jdc}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

build_and_push() {
    local arch="$1"
    local full_image="${REGISTRY}/${IMAGE_NAME}:${TAG}-${arch}"

    log_info "Building and pushing ${full_image} for ${arch}..."

    docker buildx build \
        --platform "linux/${arch}" \
        --target dev \
        -t "$full_image" \
        --build-arg "ZEROCLAW_CARGO_FEATURES=channel-lark" \
        --push \
        .

    log_success "Built and pushed ${full_image}"
}

pull_local() {
    local image="$1"
    log_info "Pulling ${image} locally..."
    docker pull "$image"
    log_success "Pulled ${image}"
}

pull_jdc() {
    local image="$1"
    log_info "Pulling ${image} on jdc..."
    ssh jdc "docker pull $image"
    log_success "Pulled ${image} on jdc"
}

restart_jdc() {
    local image="$1"
    log_info "Restarting zeroclaw-daemon on jdc..."
    ssh jdc "docker stop zeroclaw-daemon 2>/dev/null || true"
    ssh jdc "docker rm zeroclaw-daemon 2>/dev/null || true"
    ssh jdc "docker run -d --name zeroclaw-daemon --restart unless-stopped -p 42617:42617 -v /root/.zeroclaw-docker:/zeroclaw-data $image daemon"
    log_success "Restarted zeroclaw-daemon on jdc"
}

main() {
    if [[ -n "$PULL_TARGET" && "$PULL_TARGET" != "jdc" && "$PULL_TARGET" != "local" ]]; then
        log_error "Invalid argument: $PULL_TARGET. Use 'jdc', 'local', or no argument."
        exit 1
    fi

    cd "$(dirname "$0")/.."

    log_info "Building multi-arch images..."
    log_info "  Image: ${IMAGE_NAME}"
    log_info "  Tag: ${TAG}"
    log_info "  Pull target: ${PULL_TARGET:-none}"

    # Build and push for both architectures
    build_and_push "amd64"
    build_and_push "arm64"

    # Pull if requested
    if [[ "$PULL_TARGET" == "local" ]]; then
        pull_local "${REGISTRY}/${IMAGE_NAME}:${TAG}-amd64"
    elif [[ "$PULL_TARGET" == "jdc" ]]; then
        pull_jdc "${REGISTRY}/${IMAGE_NAME}:${TAG}-arm64"
        restart_jdc "${REGISTRY}/${IMAGE_NAME}:${TAG}-arm64"
    fi

    log_success "Done!"
}

main "$@"