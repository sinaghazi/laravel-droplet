#!/bin/bash

set -e

# ==============================================
# Configuration Variables (modify these)
# ==============================================
SSL_TYPE="self-signed"          # Options: "self-signed" or "letsencrypt"
DOMAIN="localhost"              # Your domain (e.g., "example.com")
EMAIL=""                        # Email for Let's Encrypt notifications

# ==============================================
# Parse command line arguments
# ==============================================
while [[ $# -gt 0 ]]; do
    case $1 in
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
        -h|--help)
            echo "Usage: ./setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --ssl=TYPE       SSL type: 'self-signed' or 'letsencrypt' (default: self-signed)"
            echo "  --domain=DOMAIN  Domain name for SSL certificate (default: localhost)"
            echo "  --email=EMAIL    Email for Let's Encrypt notifications (required for letsencrypt)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./setup.sh                                          # Self-signed SSL for localhost"
            echo "  ./setup.sh --ssl=self-signed --domain=myapp.local   # Self-signed for custom domain"
            echo "  ./setup.sh --ssl=letsencrypt --domain=example.com --email=admin@example.com"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate Let's Encrypt requirements
if [ "$SSL_TYPE" = "letsencrypt" ]; then
    if [ "$DOMAIN" = "localhost" ]; then
        echo "❌ Error: Let's Encrypt requires a real domain name, not 'localhost'"
        echo "   Use: ./setup.sh --ssl=letsencrypt --domain=yourdomain.com --email=you@email.com"
        exit 1
    fi
    if [ -z "$EMAIL" ]; then
        echo "❌ Error: Let's Encrypt requires an email address"
        echo "   Use: ./setup.sh --ssl=letsencrypt --domain=$DOMAIN --email=you@email.com"
        exit 1
    fi
fi

echo "=============================================="
echo "🚀 Laravel DigitalOcean Droplet Simulator"
echo "=============================================="
echo ""
echo "📋 Configuration:"
echo "   SSL Type: $SSL_TYPE"
echo "   Domain:   $DOMAIN"
if [ "$SSL_TYPE" = "letsencrypt" ]; then
    echo "   Email:    $EMAIL"
fi
echo ""

# Create necessary directories
echo "📁 Creating volume directories..."
mkdir -p volumes/mysql
mkdir -p volumes/apache-logs
mkdir -p volumes/php-logs
mkdir -p volumes/supervisor-logs
mkdir -p volumes/redis
mkdir -p volumes/letsencrypt

# Check if Laravel app exists
if [ ! -f "laravel-app/artisan" ]; then
    echo "❌ Error: Laravel application not found in ./laravel-app/"
    echo "   Please copy your Laravel application to ./laravel-app/ directory"
    echo "   Including: vendor folder, .env file, everything!"
    exit 1
fi

echo "✅ Laravel application detected"
echo ""

# Stop existing containers if running
echo "🛑 Stopping existing containers (if any)..."
docker-compose down 2>/dev/null || true

# Build containers
echo ""
echo "🔨 Building Docker containers..."
docker-compose build --no-cache

# Start containers
echo ""
echo "🚀 Starting containers..."
docker-compose up -d

# Wait for MySQL to be ready
echo ""
echo "⏳ Waiting for MySQL to be ready..."
until docker exec laravel-mysql mysqladmin ping -h localhost -u root -proot_password --silent 2>/dev/null; do
    echo "   MySQL is starting up..."
    sleep 3
done
echo "✅ MySQL is ready!"

# Wait a bit more for container to stabilize
sleep 3

# Set permissions inside container
echo ""
echo "🔐 Setting file permissions..."
docker exec laravel-server bash -c "
    # Set ownership to www-data (Apache user)
    chown -R www-data:www-data /var/www/html
    
    # Set directory permissions
    find /var/www/html -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find /var/www/html -type f -exec chmod 644 {} \;
    
    # Make artisan executable
    chmod +x /var/www/html/artisan
    
    # Storage and cache need to be writable
    chmod -R 775 /var/www/html/storage
    chmod -R 775 /var/www/html/bootstrap/cache
    
    # Ensure log files are writable
    touch /var/www/html/storage/logs/laravel.log
    chmod 664 /var/www/html/storage/logs/laravel.log
    chown www-data:www-data /var/www/html/storage/logs/laravel.log
"
echo "✅ Permissions set!"

# ==============================================
# SSL Certificate Setup
# ==============================================
echo ""
echo "🔒 Configuring SSL Certificate..."

if [ "$SSL_TYPE" = "letsencrypt" ]; then
    echo "   Using Let's Encrypt for domain: $DOMAIN"
    
    # Configure Apache for the domain
    docker exec laravel-server bash -c "
        # Update Apache ServerName
        sed -i 's/ServerName localhost/ServerName $DOMAIN/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/ServerName localhost/ServerName $DOMAIN/g' /etc/apache2/sites-available/default-ssl.conf
        
        # Temporarily disable HTTPS redirect for certbot challenge
        sed -i 's/RewriteEngine On/#RewriteEngine On/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/RewriteCond/#RewriteCond/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/RewriteRule/#RewriteRule/g' /etc/apache2/sites-available/000-default.conf
        
        # Disable SSL site temporarily
        a2dissite default-ssl 2>/dev/null || true
        
        # Reload Apache
        apache2ctl graceful
    "
    
    echo "   Running Certbot..."
    docker exec laravel-server certbot --apache \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --redirect
    
    echo "✅ Let's Encrypt certificate installed!"
    
    # Set up auto-renewal cron job
    docker exec laravel-server bash -c "
        echo '0 0,12 * * * root certbot renew --quiet' > /etc/cron.d/certbot-renew
        chmod 644 /etc/cron.d/certbot-renew
    "
    echo "✅ Auto-renewal cron job configured!"
    
else
    echo "   Using self-signed certificate for: $DOMAIN"
    
    # Generate new self-signed certificate with custom domain
    docker exec laravel-server bash -c "
        # Generate new certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/apache2/ssl/apache-selfsigned.key \
            -out /etc/apache2/ssl/apache-selfsigned.crt \
            -subj '/C=FI/ST=Uusimaa/L=Helsinki/O=Laravel Dev/OU=Development/CN=$DOMAIN'
        
        chmod 600 /etc/apache2/ssl/apache-selfsigned.key
        chmod 644 /etc/apache2/ssl/apache-selfsigned.crt
        
        # Update Apache ServerName
        sed -i 's/ServerName localhost/ServerName $DOMAIN/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/ServerName localhost/ServerName $DOMAIN/g' /etc/apache2/sites-available/default-ssl.conf
        
        # Reload Apache
        apache2ctl graceful
    "
    echo "✅ Self-signed certificate generated!"
fi

# Run Laravel setup commands
echo ""
echo "🔧 Running Laravel setup commands..."

# Clear all caches
echo "   Clearing caches..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan config:clear && php artisan cache:clear && php artisan view:clear && php artisan route:clear" 2>/dev/null || true

# Generate application key if not set
echo "   Checking application key..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan key:generate --force" 2>/dev/null || true

# Run migrations
echo ""
echo "📊 Running database migrations..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan migrate --force"

# Ask about seeding
echo ""
read -p "🌱 Do you want to run database seeders? (y/N): " run_seeders
if [[ "$run_seeders" =~ ^[Yy]$ ]]; then
    echo "   Running database seeders..."
    docker exec laravel-server bash -c "cd /var/www/html && php artisan db:seed --force"
    echo "✅ Seeders completed!"
fi

# Create storage link
echo ""
echo "🔗 Creating storage symlink..."
docker exec laravel-server bash -c "cd /var/www/html && php artisan storage:link --force" 2>/dev/null || true

# Cache configuration for production
echo ""
read -p "⚡ Do you want to cache configs for production? (y/N): " cache_config
if [[ "$cache_config" =~ ^[Yy]$ ]]; then
    docker exec laravel-server bash -c "cd /var/www/html && php artisan config:cache && php artisan route:cache && php artisan view:cache"
    echo "✅ Configuration cached!"
fi

# Final permission fix
docker exec laravel-server bash -c "chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache"

echo ""
echo "=============================================="
echo "✅ Setup Complete!"
echo "=============================================="
echo ""
echo "🔒 SSL Configuration:"
echo "   Type:   $SSL_TYPE"
echo "   Domain: $DOMAIN"
if [ "$SSL_TYPE" = "self-signed" ]; then
    echo "   ⚠️  Browser will show security warning (expected for self-signed)"
fi
echo ""
echo "📝 Access URLs:"
echo "   HTTPS:       https://$DOMAIN"
echo "   HTTP:        http://$DOMAIN (redirects to HTTPS)"
echo "   SSH Access:  ssh root@localhost -p 2222"
echo "                Password: password"
echo ""
echo "🗄️  Database Connection (for .env):"
echo "   DB_HOST=mysql"
echo "   DB_PORT=3306"
echo "   DB_DATABASE=laravel_db"
echo "   DB_USERNAME=laravel_user"
echo "   DB_PASSWORD=laravel_password"
echo ""
echo "📦 Redis Connection (optional, for .env):"
echo "   REDIS_HOST=redis"
echo "   REDIS_PORT=6379"
echo ""
if [ "$DOMAIN" != "localhost" ]; then
    echo "🌐 Don't forget to:"
    echo "   - Point your domain DNS to this server's IP"
    echo "   - Add '$DOMAIN' to /etc/hosts for local testing:"
    echo "     127.0.0.1 $DOMAIN"
    echo ""
fi
echo "🔧 Useful Commands:"
echo "   Shell access:     docker exec -it laravel-server bash"
echo "   View logs:        docker-compose logs -f"
echo "   Artisan:          docker exec laravel-server bash -c 'cd /var/www/html && php artisan <command>'"
echo "   Restart:          docker-compose restart"
echo "   Stop:             docker-compose down"
echo "   Rebuild:          docker-compose build --no-cache && docker-compose up -d"
if [ "$SSL_TYPE" = "letsencrypt" ]; then
    echo "   Renew SSL:        docker exec laravel-server certbot renew"
fi
echo ""
