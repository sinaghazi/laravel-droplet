# 🚀 Laravel Droplet - Docker Environment

A production-ready Docker environment that simulates a **DigitalOcean Droplet** for Laravel applications. Deploy your Laravel app in seconds with pre-configured Apache, PHP 8.4, MySQL, Redis, phpMyAdmin, and SSL support.

[![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](https://www.docker.com/)
[![PHP](https://img.shields.io/badge/PHP-8.4-purple?logo=php)](https://www.php.net/)
[![Laravel](https://img.shields.io/badge/Laravel-Compatible-red?logo=laravel)](https://laravel.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## ✨ Features

- 🐧 **Ubuntu 24.04 LTS** - Latest stable base
- 🐘 **PHP 8.4** - With all Laravel extensions pre-installed
- 🌐 **Apache** - Configured for Laravel with mod_rewrite
- 🗄️ **MySQL 8.4** - Ready to use database
- 📦 **Redis 7** - For caching, sessions, and queues
- 🔐 **SSL Support** - Self-signed or Let's Encrypt
- 🛠️ **phpMyAdmin** - Database management UI
- 📦 **Composer & Node.js** - Pre-installed
- 🔄 **Queue Worker** - Supervisor-managed Laravel queues
- ⏰ **Task Scheduler** - Laravel scheduler running automatically
- 🔌 **SSH Access** - Just like a real droplet

## 🚀 Quick Start

### Option 1: Using Pre-built Image (Recommended)

```bash
# Clone this repository
git clone https://github.com/sinaghazi/laravel-droplet.git
cd laravel-droplet

# Deploy your Laravel app
./deploy.sh --zip=/path/to/your-laravel-app.zip
```

### Option 2: Build Locally

```bash
# Clone and build
git clone https://github.com/sinaghazi/laravel-droplet.git
cd laravel-droplet
./build-image.sh --username=sinaghazi

# Deploy
./deploy.sh --zip=/path/to/your-laravel-app.zip
```

## 🌐 Access Your Application

| Service | URL | Credentials |
|---------|-----|-------------|
| Laravel App | https://localhost | - |
| phpMyAdmin | https://localhost/phpmyadmin | laravel_user / laravel_password |
| SSH | `ssh root@localhost -p 2222` | password: `password` |
| MySQL | localhost:3306 | root / root_password |
| Redis | localhost:6379 | - |

## 📁 Project Structure

```
├── deploy.sh            # Deploy Laravel app from zip
├── build-image.sh       # Build base Docker image
├── ssl-manage.sh        # Manage SSL certificates
├── docker-compose.yml   # Container orchestration
├── Dockerfile.base      # Base image definition
├── laravel-app/         # Your Laravel application
└── volumes/             # Persistent data (MySQL, logs, SSL)
```

## 🔐 SSL Configuration

### Self-Signed (Development)

```bash
./ssl-manage.sh self-signed
./ssl-manage.sh self-signed myapp.local
```

### Let's Encrypt (Production)

```bash
./ssl-manage.sh letsencrypt example.com admin@example.com
```

## 📋 Useful Commands

```bash
# Access container shell
docker exec -it laravel-server bash

# Run artisan commands
docker exec laravel-server bash -c "cd /var/www/html && php artisan migrate"

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop everything
docker-compose down
```

## 🗄️ Database Configuration

Add these to your Laravel `.env` file:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=laravel_user
DB_PASSWORD=laravel_password

REDIS_HOST=redis
REDIS_PORT=6379
```

## 🐳 Pre-built Image

Pull the pre-built image for faster deployments:

```bash
docker pull sinaghazi/laravel-droplet:latest
```

Or build your own:

```bash
./build-image.sh --username=sinaghazi --push
```

## 📦 What's Included

### PHP Extensions
`bcmath`, `curl`, `fileinfo`, `gd`, `imagick`, `intl`, `mbstring`, `mysql`, `opcache`, `readline`, `redis`, `soap`, `xml`, `zip`

### System Tools
`composer`, `node`, `npm`, `git`, `vim`, `nano`, `htop`, `curl`, `wget`, `unzip`, `certbot`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open-sourced software licensed under the [MIT license](LICENSE).

---

**⭐ If this helped you, please give it a star!**

