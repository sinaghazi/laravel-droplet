#!/bin/bash

# ==============================================
# Laravel Droplet Deployment Script
# ==============================================
# 
# Usage:
#   ./deploy.sh                           # Interactive mode
#   ./deploy.sh --zip=/path/to/app.zip    # Deploy from zip file
#   ./deploy.sh --image=user/image:tag    # Use custom Docker image
#
# ==============================================

set -e

# ==============================================
# Configuration
# ==============================================
DOCKER_IMAGE="sinaghazi/laravel-droplet:latest"
ZIP_FILE=""
SSL_TYPE="self-signed"
DOMAIN="localhost"
EMAIL=""
SKIP_PROMPTS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================================
# Parse Arguments
# ==============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --zip=*)
            ZIP_FILE="${1#*=}"
            shift
            ;;
        --image=*)
            DOCKER_IMAGE="${1#*=}"
            shift
            ;;
        --ssl=*)
            SSL_TYPE="${1#*=}"
            shift
            ;;
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --email=*)
            EMAIL="${1#*=}"
            shift
            ;;
        --yes|-y)
            SKIP_PROMPTS=true
            shift
            ;;
        -h|--help)
            echo "Laravel Droplet Deployment Script"
            echo ""
            echo "Usage: ./deploy.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --zip=PATH         Path to Laravel application zip file"
            echo "  --image=IMAGE      Docker image to use (default: $DOCKER_IMAGE)"
            echo "  --ssl=TYPE         SSL type: 'self-signed' or 'letsencrypt'"
            echo "  --domain=DOMAIN    Domain name (default: localhost)"
            echo "  --email=EMAIL      Email for Let's Encrypt"
            echo "  --yes, -y          Skip confirmation prompts"
            echo "  -h, --help         Show this help"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh --zip=~/Downloads/laravel-app.zip"
            echo "  ./deploy.sh --zip=app.zip --ssl=letsencrypt --domain=example.com --email=admin@example.com"
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
clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Laravel DigitalOcean Droplet Simulator             ║"
echo "║                    Deployment Script                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ==============================================
# Step 1: Create Directories
# ==============================================
echo -e "${YELLOW}📁 Step 1: Creating directories...${NC}"
mkdir -p volumes/mysql
mkdir -p volumes/apache-logs
mkdir -p volumes/php-logs
mkdir -p volumes/supervisor-logs
mkdir -p volumes/redis
mkdir -p volumes/letsencrypt
mkdir -p volumes/ssl
mkdir -p laravel-app
echo -e "${GREEN}✅ Directories created${NC}"
echo ""

# ==============================================
# Step 2: Start Containers
# ==============================================
echo -e "${YELLOW}🐳 Step 2: Starting Docker containers...${NC}"
echo "   Image: $DOCKER_IMAGE"

# Export image for docker-compose
export DOCKER_IMAGE

# Stop existing containers
docker-compose down 2>/dev/null || true

# Pull and start
echo "   Pulling image..."
docker-compose pull laravel-droplet 2>/dev/null || {
    echo -e "${YELLOW}   Image not found on registry, building locally...${NC}"
    docker-compose build
}

echo "   Starting containers..."
docker-compose up -d

# Wait for MySQL
echo "   Waiting for MySQL to be ready..."
until docker exec laravel-mysql mysqladmin ping -h localhost -u root -proot_password --silent 2>/dev/null; do
    sleep 2
done
echo -e "${GREEN}✅ Containers started${NC}"
echo ""

# ==============================================
# Step 3: Deploy Laravel Application
# ==============================================
echo -e "${YELLOW}📦 Step 3: Deploying Laravel application...${NC}"

if [ -n "$ZIP_FILE" ]; then
    # Zip file provided via argument
    if [ ! -f "$ZIP_FILE" ]; then
        echo -e "${RED}❌ Error: Zip file not found: $ZIP_FILE${NC}"
        exit 1
    fi
    echo "   Using zip file: $ZIP_FILE"
else
    # Check if laravel-app already has files
    if [ -f "laravel-app/artisan" ]; then
        echo "   Laravel application already exists in ./laravel-app/"
        if [ "$SKIP_PROMPTS" = false ]; then
            read -p "   Do you want to keep existing files? (Y/n): " keep_existing
            if [[ "$keep_existing" =~ ^[Nn]$ ]]; then
                rm -rf laravel-app/*
            fi
        fi
    fi
    
    # Ask for zip file if laravel-app is empty
    if [ ! -f "laravel-app/artisan" ]; then
        echo ""
        echo "   No Laravel application found."
        echo "   You can either:"
        echo "   1. Provide a zip file path"
        echo "   2. Manually copy files to ./laravel-app/"
        echo ""
        read -p "   Enter path to zip file (or press Enter to skip): " ZIP_FILE
    fi
fi

# Extract zip file if provided
if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo "   Extracting zip file..."
    
    # Create temp directory for extraction
    TEMP_DIR=$(mktemp -d)
    unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
    
    # Find the Laravel root (directory containing artisan)
    LARAVEL_ROOT=$(find "$TEMP_DIR" -name "artisan" -type f -exec dirname {} \; | head -1)
    
    if [ -z "$LARAVEL_ROOT" ]; then
        echo -e "${RED}❌ Error: No Laravel application found in zip file${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clear laravel-app and copy files
    rm -rf laravel-app/*
    cp -r "$LARAVEL_ROOT"/* laravel-app/
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✅ Application extracted to ./laravel-app/${NC}"
fi

# Verify Laravel app exists
if [ ! -f "laravel-app/artisan" ]; then
    echo -e "${YELLOW}⚠️  No Laravel application in ./laravel-app/${NC}"
    echo "   Please copy your Laravel application files to ./laravel-app/"
    echo "   Then run: ./deploy.sh --yes"
    exit 0
fi

echo -e "${GREEN}✅ Laravel application ready${NC}"
echo ""

# ==============================================
# Step 4: Configure Application
# ==============================================
echo -e "${YELLOW}⚙️  Step 4: Configuring application...${NC}"

# Set permissions
echo "   Setting file permissions..."
docker exec laravel-server bash -c "
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    chmod +x /var/www/html/artisan 2>/dev/null || true
    chmod -R 775 /var/www/html/storage 2>/dev/null || true
    chmod -R 775 /var/www/html/bootstrap/cache 2>/dev/null || true
"

# Generate SSL certificate
echo "   Generating SSL certificate..."
docker exec laravel-server bash -c "
    if [ ! -f /etc/apache2/ssl/apache-selfsigned.crt ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/apache2/ssl/apache-selfsigned.key \
            -out /etc/apache2/ssl/apache-selfsigned.crt \
            -subj '/C=FI/ST=Uusimaa/L=Helsinki/O=Laravel Dev/CN=$DOMAIN'
        chmod 600 /etc/apache2/ssl/apache-selfsigned.key
        chmod 644 /etc/apache2/ssl/apache-selfsigned.crt
    fi
    apache2ctl graceful 2>/dev/null || true
"

# Check for .env file
if [ ! -f "laravel-app/.env" ]; then
    if [ -f "laravel-app/.env.example" ]; then
        echo "   Creating .env from .env.example..."
        cp laravel-app/.env.example laravel-app/.env
    fi
fi

# Update .env with Docker database settings
if [ -f "laravel-app/.env" ]; then
    echo "   Updating .env with database settings..."
    # Use sed to update database settings
    sed -i.bak 's/DB_HOST=.*/DB_HOST=mysql/' laravel-app/.env 2>/dev/null || true
    sed -i.bak 's/DB_DATABASE=.*/DB_DATABASE=laravel_db/' laravel-app/.env 2>/dev/null || true
    sed -i.bak 's/DB_USERNAME=.*/DB_USERNAME=laravel_user/' laravel-app/.env 2>/dev/null || true
    sed -i.bak 's/DB_PASSWORD=.*/DB_PASSWORD=laravel_password/' laravel-app/.env 2>/dev/null || true
    sed -i.bak 's/REDIS_HOST=.*/REDIS_HOST=redis/' laravel-app/.env 2>/dev/null || true
    rm -f laravel-app/.env.bak 2>/dev/null || true
fi

echo -e "${GREEN}✅ Configuration complete${NC}"
echo ""

# ==============================================
# Step 5: Laravel Setup
# ==============================================
echo -e "${YELLOW}🔧 Step 5: Running Laravel setup...${NC}"

# Clear caches
echo "   Clearing caches..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan config:clear && php artisan cache:clear" 2>/dev/null || true

# Generate key
echo "   Generating application key..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan key:generate --force" 2>/dev/null || true

# Run migrations
echo "   Running migrations..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan migrate --force" 2>/dev/null || {
    echo -e "${YELLOW}   ⚠️  Migrations skipped (may need manual setup)${NC}"
}

# Ask about seeding
if [ "$SKIP_PROMPTS" = false ]; then
    echo ""
    read -p "   🌱 Run database seeders? (y/N): " run_seeders
    if [[ "$run_seeders" =~ ^[Yy]$ ]]; then
        docker exec laravel-server bash -c "cd /var/www/html && php artisan db:seed --force"
        echo -e "${GREEN}   ✅ Seeders completed${NC}"
    fi
fi

# Storage link
echo "   Creating storage link..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan storage:link --force" 2>/dev/null || true

# Final permissions
docker exec laravel-server bash -c "chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache" 2>/dev/null || true

echo -e "${GREEN}✅ Laravel setup complete${NC}"
echo ""

# ==============================================
# Complete!
# ==============================================
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🎉 Deployment Complete!                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "🌐 Access URLs:"
echo "   Laravel App:    https://localhost"
echo "   phpMyAdmin:     https://localhost/phpmyadmin"
echo "   SSH:            ssh root@localhost -p 2222 (password: password)"
echo ""
echo "🗄️  Database Credentials:"
echo "   Host:     mysql (or localhost:3306 from host)"
echo "   Database: laravel_db"
echo "   Username: laravel_user"
echo "   Password: laravel_password"
echo "   Root:     root / root_password"
echo ""
echo "🔧 Useful Commands:"
echo "   docker exec -it laravel-server bash           # Shell access"
echo "   docker-compose logs -f                        # View logs"
echo "   docker-compose restart                        # Restart services"
echo "   docker-compose down                           # Stop all"
echo ""

