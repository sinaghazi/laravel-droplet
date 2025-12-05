#!/bin/bash
# ==============================================
# Build Laravel Droplet Image
# ==============================================

set -e

DOCKER_USERNAME="${DOCKER_USERNAME:-sinaghazi}"
IMAGE_NAME="laravel-droplet"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --username=*) DOCKER_USERNAME="${1#*=}"; FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"; shift ;;
        --tag=*) IMAGE_TAG="${1#*=}"; FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"; shift ;;
        --push) DO_PUSH=true; shift ;;
        --no-cache) NO_CACHE="--no-cache"; shift ;;
        -h|--help)
            echo "Usage: ./build-image.sh [OPTIONS]"
            echo "  --username=NAME   Docker Hub username"
            echo "  --tag=TAG         Image tag (default: latest)"
            echo "  --push            Push to Docker Hub"
            echo "  --no-cache        Build without cache"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "╔════════════════════════════════════════════╗"
echo "║     Laravel Droplet - Image Builder        ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "📦 Building: $FULL_IMAGE"
echo ""

# Build
docker build -f Dockerfile.base -t "$FULL_IMAGE" $NO_CACHE .

echo ""
echo "✅ Image built: $FULL_IMAGE"

# Push if requested
if [ "$DO_PUSH" = true ]; then
    echo ""
    echo "🚀 Pushing to Docker Hub..."
    docker push "$FULL_IMAGE"
    echo "✅ Pushed!"
fi

echo ""
echo "📋 To use: docker-compose up -d"
echo ""
