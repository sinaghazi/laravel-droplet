#!/bin/bash
# ==============================================
# FileBrowser Setup Script
# ==============================================
# Sets up FileBrowser with custom admin credentials
# Usage: ./filebrowser-setup.sh [username] [password]
# ==============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get custom credentials from arguments or prompt
USERNAME="${1:-}"
PASSWORD="${2:-}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     FileBrowser Setup                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Create volumes directory if it doesn't exist
mkdir -p ./volumes/filebrowser

# Check if database already exists
if [ -f "./volumes/filebrowser/filebrowser.db" ]; then
    echo -e "${YELLOW}⚠️  FileBrowser database already exists.${NC}"
    read -p "Do you want to reset it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Keeping existing configuration.${NC}"
        echo -e "${BLUE}ℹ️  Access FileBrowser at: http://localhost:8080${NC}"
        exit 0
    fi
    rm -f ./volumes/filebrowser/filebrowser.db
    echo -e "${GREEN}✓ Database reset.${NC}"
fi

# Prompt for credentials if not provided
if [ -z "$USERNAME" ]; then
    read -p "Enter admin username [admin]: " USERNAME
    USERNAME="${USERNAME:-admin}"
fi

if [ -z "$PASSWORD" ]; then
    read -s -p "Enter admin password [admin]: " PASSWORD
    echo
    PASSWORD="${PASSWORD:-admin}"
fi

echo ""
echo -e "${BLUE}Setting up FileBrowser...${NC}"

# Initialize the database with custom credentials using a temporary container
echo -e "${BLUE}Initializing database with admin user...${NC}"

docker run --rm \
    -v "$(pwd)/volumes/filebrowser:/database" \
    -v "$(pwd)/config/filebrowser.json:/.filebrowser.json:ro" \
    filebrowser/filebrowser:latest \
    config init 2>/dev/null || true

docker run --rm \
    -v "$(pwd)/volumes/filebrowser:/database" \
    -v "$(pwd)/config/filebrowser.json:/.filebrowser.json:ro" \
    filebrowser/filebrowser:latest \
    users add "$USERNAME" "$PASSWORD" --perm.admin 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Admin user '$USERNAME' created successfully.${NC}"
else
    echo -e "${YELLOW}⚠️  User may already exist or there was an issue.${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     FileBrowser Setup Complete!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Access FileBrowser:${NC}"
echo -e "  URL:      ${GREEN}http://localhost:8080${NC}"
echo -e "  Username: ${GREEN}$USERNAME${NC}"
echo -e "  Password: ${GREEN}(as entered)${NC}"
echo ""
echo -e "${BLUE}To start FileBrowser, run:${NC}"
echo -e "  ${YELLOW}docker-compose up -d filebrowser${NC}"
echo ""
echo -e "${BLUE}Or start all services:${NC}"
echo -e "  ${YELLOW}docker-compose up -d${NC}"
echo ""

