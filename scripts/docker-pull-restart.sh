#!/bin/bash
# Pull ZeroClaw Docker image and restart container
#
# Usage:
#   ./scripts/docker-pull-restart.sh [TARGET]
#
# Arguments:
#   TARGET    Where to pull: "jdc" or "local" (default: jdc)

set -euo pipefail

# Hardcoded configuration
TAG="latest"
REGISTRY="registry.cn-hangzhou.aliyuncs.com/cwpypy"
IMAGE_NAME="zeroclaw-with-lark"

# Target from argument (default: jdc)
TARGET="${1:-jdc}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

pull_and_restart_local() {
    local image="${REGISTRY}/${IMAGE_NAME}:${TAG}-amd64"

    log_info "Pulling ${image} locally..."
    docker pull "$image"
    log_success "Pulled ${image}"

    log_info "Stopping zeroclaw-daemon..."
    docker stop zeroclaw-daemon 2>/dev/null || true
    docker rm zeroclaw-daemon 2>/dev/null || true

    log_info "Starting zeroclaw-daemon..."
    docker run -d --name zeroclaw-daemon --restart unless-stopped \
        -p 42617:42617 \
        -v ~/.zeroclaw:/zeroclaw-data \
        "$image" \
        daemon

    log_success "Restarted zeroclaw-daemon locally"
}

pull_and_restart_jdc() {
    local image="${REGISTRY}/${IMAGE_NAME}:${TAG}-arm64"
    
    log_info "Pulling ${image} on jdc..."
    ssh jdc "docker pull $image"
    log_success "Pulled ${image} on jdc"
    
    log_info "Restarting zeroclaw-daemon on jdc..."
    ssh jdc "docker stop zeroclaw-daemon 2>/dev/null || true"
    ssh jdc "docker rm zeroclaw-daemon 2>/dev/null || true"
    ssh jdc "docker run -d --name zeroclaw-daemon --restart unless-stopped -p 42617:42617 -v /root/.zeroclaw-docker:/zeroclaw-data $image daemon"
    log_success "Restarted zeroclaw-daemon on jdc"
}

main() {
    if [[ "$TARGET" != "jdc" && "$TARGET" != "local" ]]; then
        log_error "Invalid argument: $TARGET. Use 'jdc' or 'local'"
        exit 1
    fi

    log_info "Pull target: ${TARGET}"
    log_info "Image: ${REGISTRY}/${IMAGE_NAME}:${TAG}"

    if [[ "$TARGET" == "local" ]]; then
        pull_and_restart_local
    else
        pull_and_restart_jdc
    fi

    log_success "Done!"
}

main "$@"
