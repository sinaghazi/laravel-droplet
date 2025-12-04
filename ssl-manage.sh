#!/bin/bash

# ==============================================
# SSL Certificate Management Script
# Use this to switch between self-signed and Let's Encrypt
# ==============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    echo "SSL Certificate Management Script"
    echo ""
    echo "Usage: ./ssl-manage.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  self-signed [domain]        Generate a self-signed certificate"
    echo "  letsencrypt <domain> <email> Obtain Let's Encrypt certificate"
    echo "  renew                        Renew Let's Encrypt certificates"
    echo "  status                       Show current SSL certificate status"
    echo "  help                         Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./ssl-manage.sh self-signed                    # Self-signed for localhost"
    echo "  ./ssl-manage.sh self-signed myapp.local        # Self-signed for custom domain"
    echo "  ./ssl-manage.sh letsencrypt example.com admin@example.com"
    echo "  ./ssl-manage.sh renew"
    echo "  ./ssl-manage.sh status"
    echo ""
}

check_container() {
    if ! docker ps | grep -q laravel-server; then
        echo -e "${RED}❌ Error: laravel-server container is not running${NC}"
        echo "   Start it with: docker-compose up -d"
        exit 1
    fi
}

generate_self_signed() {
    local DOMAIN=${1:-localhost}
    
    echo -e "${YELLOW}🔒 Generating self-signed certificate for: $DOMAIN${NC}"
    
    docker exec laravel-server bash -c "
        # Generate new certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/apache2/ssl/apache-selfsigned.key \
            -out /etc/apache2/ssl/apache-selfsigned.crt \
            -subj '/C=FI/ST=Uusimaa/L=Helsinki/O=Laravel Dev/OU=Development/CN=$DOMAIN'
        
        chmod 600 /etc/apache2/ssl/apache-selfsigned.key
        chmod 644 /etc/apache2/ssl/apache-selfsigned.crt
        
        # Update Apache ServerName
        sed -i \"s/ServerName .*/ServerName $DOMAIN/g\" /etc/apache2/sites-available/000-default.conf
        sed -i \"s/ServerName .*/ServerName $DOMAIN/g\" /etc/apache2/sites-available/default-ssl.conf
        
        # Ensure self-signed SSL config is active
        cat > /etc/apache2/sites-available/default-ssl.conf << 'SSLEOF'
<VirtualHost *:443>
    ServerAdmin admin@localhost
    ServerName $DOMAIN
    DocumentRoot /var/www/html/public
    
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/apache-selfsigned.crt
    SSLCertificateKeyFile /etc/apache2/ssl/apache-selfsigned.key
    
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionTickets off
    
    Header always set Strict-Transport-Security \"max-age=63072000\"
    
    <Directory /var/www/html/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    <FilesMatch \"\\.php\$\">
        SSLOptions +StdEnvVars
    </FilesMatch>
    
    ServerSignature Off
    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined
</VirtualHost>
SSLEOF
        
        # Re-enable default-ssl and reload Apache
        a2ensite default-ssl 2>/dev/null || true
        apache2ctl graceful
    "
    
    echo -e "${GREEN}✅ Self-signed certificate generated!${NC}"
    echo ""
    echo "Certificate details:"
    docker exec laravel-server openssl x509 -in /etc/apache2/ssl/apache-selfsigned.crt -noout -subject -dates
    echo ""
    echo -e "${YELLOW}⚠️  Browser will show security warning (expected for self-signed)${NC}"
}

install_letsencrypt() {
    local DOMAIN=$1
    local EMAIL=$2
    
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        echo -e "${RED}❌ Error: Domain and email are required${NC}"
        echo "Usage: ./ssl-manage.sh letsencrypt <domain> <email>"
        exit 1
    fi
    
    if [ "$DOMAIN" = "localhost" ]; then
        echo -e "${RED}❌ Error: Let's Encrypt requires a real domain, not 'localhost'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🔒 Installing Let's Encrypt certificate for: $DOMAIN${NC}"
    echo "   Email: $EMAIL"
    echo ""
    
    # First, update Apache config for the domain
    docker exec laravel-server bash -c "
        # Update ServerName
        sed -i \"s/ServerName .*/ServerName $DOMAIN/g\" /etc/apache2/sites-available/000-default.conf
        
        # Temporarily disable HTTPS redirect for certbot
        sed -i 's/RewriteEngine On/#RewriteEngine On/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/RewriteCond/#RewriteCond/g' /etc/apache2/sites-available/000-default.conf
        sed -i 's/RewriteRule/#RewriteRule/g' /etc/apache2/sites-available/000-default.conf
        
        # Disable SSL site temporarily
        a2dissite default-ssl 2>/dev/null || true
        
        # Reload Apache
        apache2ctl graceful
    "
    
    echo "Running Certbot..."
    docker exec laravel-server certbot --apache \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --redirect
    
    # Set up auto-renewal
    docker exec laravel-server bash -c "
        echo '0 0,12 * * * root certbot renew --quiet' > /etc/cron.d/certbot-renew
        chmod 644 /etc/cron.d/certbot-renew
    "
    
    echo ""
    echo -e "${GREEN}✅ Let's Encrypt certificate installed!${NC}"
    echo "✅ Auto-renewal cron job configured!"
    echo ""
    echo "Certificate details:"
    docker exec laravel-server certbot certificates
}

renew_letsencrypt() {
    echo -e "${YELLOW}🔄 Renewing Let's Encrypt certificates...${NC}"
    docker exec laravel-server certbot renew
    echo -e "${GREEN}✅ Renewal check complete!${NC}"
}

show_status() {
    echo "=============================================="
    echo "🔒 SSL Certificate Status"
    echo "=============================================="
    echo ""
    
    # Check for self-signed cert
    if docker exec laravel-server test -f /etc/apache2/ssl/apache-selfsigned.crt 2>/dev/null; then
        echo "📜 Self-Signed Certificate:"
        docker exec laravel-server openssl x509 -in /etc/apache2/ssl/apache-selfsigned.crt -noout -subject -dates 2>/dev/null || echo "   (unable to read)"
        echo ""
    fi
    
    # Check for Let's Encrypt
    echo "📜 Let's Encrypt Certificates:"
    docker exec laravel-server certbot certificates 2>/dev/null || echo "   No Let's Encrypt certificates found"
    echo ""
    
    # Show Apache SSL status
    echo "🌐 Apache SSL Configuration:"
    docker exec laravel-server apache2ctl -S 2>/dev/null | grep -E "(443|SSL)" || echo "   (unable to determine)"
    echo ""
}

# ==============================================
# Main Script
# ==============================================

case "${1:-help}" in
    self-signed)
        check_container
        generate_self_signed "$2"
        ;;
    letsencrypt)
        check_container
        install_letsencrypt "$2" "$3"
        ;;
    renew)
        check_container
        renew_letsencrypt
        ;;
    status)
        check_container
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

