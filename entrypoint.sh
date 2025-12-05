#!/bin/bash

# ==============================================
# Entrypoint Script for Laravel Docker Container
# ==============================================

set -e

echo "🚀 Starting Laravel Droplet Container..."

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
