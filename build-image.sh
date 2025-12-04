#!/bin/bash

# ==============================================
# Build and Push Laravel Droplet Base Image
# ==============================================
# 
# This script builds the base image and pushes it to Docker Hub
# Run this ONCE to create your public image
#
# Prerequisites:
#   1. Docker Hub account
#   2. docker login (run: docker login)
#
# ==============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================================
# Configuration - CHANGE THESE!
# ==============================================
DOCKER_USERNAME="${DOCKER_USERNAME:-sinaghazi}"
IMAGE_NAME="laravel-droplet"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Full image name
FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

# ==============================================
# Parse Arguments
# ==============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --username=*)
            DOCKER_USERNAME="${1#*=}"
            FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
            shift
            ;;
        --tag=*)
            IMAGE_TAG="${1#*=}"
            FULL_IMAGE="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
            shift
            ;;
        --push)
            DO_PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -h|--help)
            echo "Build Laravel Droplet Base Image"
            echo ""
            echo "Usage: ./build-image.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --username=NAME   Docker Hub username (default: yourusername)"
            echo "  --tag=TAG         Image tag (default: latest)"
            echo "  --push            Push to Docker Hub after building"
            echo "  --no-cache        Build without using cache"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  DOCKER_USERNAME   Docker Hub username"
            echo "  IMAGE_TAG         Image tag"
            echo ""
            echo "Examples:"
            echo "  ./build-image.sh --username=myuser --push"
            echo "  ./build-image.sh --username=myuser --tag=v1.0 --push"
            echo "  DOCKER_USERNAME=myuser ./build-image.sh --push"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# ==============================================
# Banner
# ==============================================
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Laravel Droplet - Base Image Builder               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "📦 Image: $FULL_IMAGE"
echo ""

# ==============================================
# Check Prerequisites
# ==============================================
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check if Dockerfile.base exists
if [ ! -f "Dockerfile.base" ]; then
    echo -e "${RED}❌ Error: Dockerfile.base not found${NC}"
    exit 1
fi

# Check if supervisord.conf exists
if [ ! -f "supervisord.conf" ]; then
    echo -e "${RED}❌ Error: supervisord.conf not found${NC}"
    exit 1
fi

# Check if entrypoint.sh exists
if [ ! -f "entrypoint.sh" ]; then
    echo -e "${RED}❌ Error: entrypoint.sh not found${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Error: Docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# ==============================================
# Build Image
# ==============================================
echo -e "${YELLOW}🔨 Building image...${NC}"
echo "   This may take 5-10 minutes on first build..."
echo ""

docker build \
    -f Dockerfile.base \
    -t "$FULL_IMAGE" \
    -t "$DOCKER_USERNAME/$IMAGE_NAME:latest" \
    $NO_CACHE \
    .

echo ""
echo -e "${GREEN}✅ Image built successfully: $FULL_IMAGE${NC}"
echo ""

# ==============================================
# Push to Docker Hub
# ==============================================
if [ "$DO_PUSH" = true ]; then
    echo -e "${YELLOW}🚀 Pushing to Docker Hub...${NC}"
    
    # Check if logged in
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo -e "${YELLOW}   You need to login to Docker Hub first${NC}"
        docker login
    fi
    
    docker push "$FULL_IMAGE"
    
    if [ "$IMAGE_TAG" != "latest" ]; then
        docker push "$DOCKER_USERNAME/$IMAGE_NAME:latest"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Image pushed to Docker Hub!${NC}"
    echo ""
    echo "🌐 Your image is now available at:"
    echo "   https://hub.docker.com/r/$DOCKER_USERNAME/$IMAGE_NAME"
    echo ""
    echo "📋 To use this image, update docker-compose.yml:"
    echo "   image: $FULL_IMAGE"
    echo ""
else
    echo -e "${YELLOW}ℹ️  Image built locally. To push to Docker Hub:${NC}"
    echo "   ./build-image.sh --username=$DOCKER_USERNAME --push"
    echo ""
fi

# ==============================================
# Image Info
# ==============================================
echo "📊 Image Details:"
docker images "$FULL_IMAGE" --format "   Size: {{.Size}}\n   Created: {{.CreatedAt}}"
echo ""

# ==============================================
# Next Steps
# ==============================================
echo -e "${BLUE}📋 Next Steps:${NC}"
echo ""
echo "1. Update docker-compose.yml with your image:"
echo "   image: $FULL_IMAGE"
echo ""
echo "2. Deploy your Laravel app:"
echo "   ./deploy.sh --zip=/path/to/your-app.zip"
echo ""

