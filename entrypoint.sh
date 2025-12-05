#!/bin/bash
# ==============================================
# Laravel Droplet Entrypoint
# Copies setup wizard to volume if empty
# ==============================================

# If public folder doesn't exist or is empty, copy the setup wizard
if [ ! -f /var/www/html/public/index.php ] && [ ! -f /var/www/html/public/index.html ]; then
    echo "📦 First run detected - setting up upload wizard..."
    mkdir -p /var/www/html/public
    cp /opt/landing.php /var/www/html/public/index.php
    chown -R www-data:www-data /var/www/html
    chmod -R 775 /var/www/html
    echo "✅ Upload wizard ready at http://localhost"
fi

# Start Apache
exec apachectl -D FOREGROUND

