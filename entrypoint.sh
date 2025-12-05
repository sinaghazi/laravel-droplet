#!/bin/bash

# ==============================================
# Entrypoint Script for Laravel Docker Container
# Handles SSL certificate generation at runtime
# ==============================================

set -e

echo "🚀 Starting Laravel Droplet Container..."

# ==============================================
# Skip SSL generation if in Coolify mode
# (Coolify handles SSL via Traefik)
# ==============================================
if [ -n "$COOLIFY_MODE" ] || [ -n "$SKIP_SSL" ]; then
    echo "🌐 Coolify mode detected - skipping SSL generation"
    # Disable SSL site since we don't have certificates
    a2dissite default-ssl 2>/dev/null || true
else
    # ==============================================
    # Generate Self-Signed SSL Certificate if not exists
    # ==============================================
    SSL_CERT="/etc/apache2/ssl/apache-selfsigned.crt"
    SSL_KEY="/etc/apache2/ssl/apache-selfsigned.key"
    
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        echo "🔒 Generating self-signed SSL certificate..."
        
        # Create SSL directory if not exists
        mkdir -p /etc/apache2/ssl
        
        # Generate self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_KEY" \
            -out "$SSL_CERT" \
            -subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Laravel Dev/OU=Development/CN=localhost"
        
        # Set permissions
        chmod 600 "$SSL_KEY"
        chmod 644 "$SSL_CERT"
        
        echo "✅ Self-signed SSL certificate generated!"
    else
        echo "✅ SSL certificates already exist, skipping generation."
    fi
fi

# ==============================================
# Verify Apache configuration
# ==============================================
echo "🔍 Verifying Apache configuration..."
apache2ctl configtest

# ==============================================
# Execute the main command (supervisord)
# ==============================================
echo "✅ Container initialized successfully!"
echo ""

exec "$@"
