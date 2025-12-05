#!/bin/bash
# ==============================================
# Laravel Droplet - Deployment Script
# ==============================================

set -e

echo "╔════════════════════════════════════════════╗"
echo "║     Laravel Droplet - Deployment           ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Build and start containers
echo "🔨 Building image..."
docker-compose build

echo ""
echo "🚀 Starting containers..."
docker-compose up -d

# Wait for MySQL
echo "⏳ Waiting for MySQL..."
until docker exec laravel-mysql mysqladmin ping -h localhost -u root -proot_password --silent 2>/dev/null; do
    sleep 2
done
echo "✅ MySQL ready!"

echo ""
echo "════════════════════════════════════════════"
echo "✅ Deployment Complete!"
echo "════════════════════════════════════════════"
echo ""
echo "🌐 Access: http://localhost"
echo "   Upload your Laravel .zip to get started"
echo ""
echo "🗄️  Database:"
echo "   Host:     mysql (or localhost:3306)"
echo "   Database: laravel"
echo "   Username: laravel"
echo "   Password: laravel"
echo ""
echo "🔧 Commands:"
echo "   docker exec -it laravel-server bash"
echo "   docker-compose logs -f"
echo "   docker-compose down"
echo ""
