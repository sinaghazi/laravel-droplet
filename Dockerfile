FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Helsinki

# Update and install everything like a fresh DigitalOcean droplet
RUN apt-get update && apt-get upgrade -y

# Install Apache + PHP 8.4 (latest stable)
RUN apt-get install -y \
    apache2 \
    software-properties-common \
    && add-apt-repository ppa:ondrej/php -y \
    && apt-get update

# Install PHP and all common Laravel extensions
# Note: php-json is built into PHP core since PHP 8.0, no separate package needed
RUN apt-get install -y \
    php8.4 \
    php8.4-cli \
    php8.4-common \
    php8.4-mysql \
    php8.4-zip \
    php8.4-gd \
    php8.4-mbstring \
    php8.4-curl \
    php8.4-xml \
    php8.4-bcmath \
    php8.4-intl \
    php8.4-soap \
    php8.4-redis \
    php8.4-opcache \
    php8.4-readline \
    php8.4-imagick \
    php8.4-fileinfo \
    libapache2-mod-php8.4

# Install Composer (essential for Laravel)
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install Node.js and npm (for Laravel Mix/Vite if needed)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install other essential tools (like a real droplet)
RUN apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    dnsutils \
    openssh-server \
    supervisor \
    cron \
    mysql-client \
    certbot \
    python3-certbot-apache \
    openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules (including SSL)
RUN a2enmod rewrite ssl headers expires socache_shmcb

# Create SSL directory
RUN mkdir -p /etc/apache2/ssl

# Configure Apache HTTP VirtualHost (with redirect to HTTPS)
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin admin@localhost\n\
    ServerName localhost\n\
    DocumentRoot /var/www/html/public\n\
    \n\
    # Redirect all HTTP to HTTPS\n\
    RewriteEngine On\n\
    RewriteCond %{HTTPS} off\n\
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]\n\
    \n\
    <Directory /var/www/html/public>\n\
        Options -Indexes +FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    \n\
    ServerSignature Off\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# Configure Apache HTTPS VirtualHost with SSL
RUN echo '<VirtualHost *:443>\n\
    ServerAdmin admin@localhost\n\
    ServerName localhost\n\
    DocumentRoot /var/www/html/public\n\
    \n\
    # SSL Configuration\n\
    SSLEngine on\n\
    SSLCertificateFile /etc/apache2/ssl/apache-selfsigned.crt\n\
    SSLCertificateKeyFile /etc/apache2/ssl/apache-selfsigned.key\n\
    \n\
    # Modern SSL settings\n\
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1\n\
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384\n\
    SSLHonorCipherOrder off\n\
    SSLSessionTickets off\n\
    \n\
    # HSTS Header\n\
    Header always set Strict-Transport-Security "max-age=63072000"\n\
    \n\
    <Directory /var/www/html/public>\n\
        Options -Indexes +FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    \n\
    <FilesMatch "\\.php$">\n\
        SSLOptions +StdEnvVars\n\
    </FilesMatch>\n\
    \n\
    ServerSignature Off\n\
    ErrorLog ${APACHE_LOG_DIR}/ssl_error.log\n\
    CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/default-ssl.conf

# Enable the SSL site
RUN a2ensite default-ssl

# Security: Hide Apache version
RUN echo "ServerTokens Prod" >> /etc/apache2/apache2.conf \
    && echo "ServerSignature Off" >> /etc/apache2/apache2.conf

# PHP configuration for Laravel (production-ready)
RUN sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/max_input_time = .*/max_input_time = 300/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' /etc/php/8.4/apache2/php.ini \
    && sed -i 's/expose_php = .*/expose_php = Off/' /etc/php/8.4/apache2/php.ini

# Same settings for CLI
RUN sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.4/cli/php.ini \
    && sed -i 's/max_execution_time = .*/max_execution_time = 0/' /etc/php/8.4/cli/php.ini

# Setup SSH (for droplet simulation)
RUN mkdir -p /var/run/sshd \
    && echo 'root:password' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create working directory
WORKDIR /var/www/html

# Create supervisor config directory
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 80 443 22

# Use entrypoint to handle SSL setup at runtime
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
