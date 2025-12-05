# Laravel Droplet

Minimal Docker environment for Laravel: **Apache + PHP 8.4 + MySQL**

## Quick Start

```bash
git clone https://github.com/sinaghazi/laravel-droplet.git
cd laravel-droplet
./deploy.sh
```

Open http://localhost

## Persistent Volume

Your Laravel files live in a Docker volume (`www_data`) at `/var/www/html`. Apache has full read/write access.

```bash
# Access shell to manage files
docker exec -it laravel-server bash

# You're now in /var/www/html as www-data
```

## Database

| Setting  | Value          |
|----------|----------------|
| Host     | `mysql`        |
| Port     | `3306`         |
| Database | `laravel`      |
| Username | `laravel`      |
| Password | `laravel`      |

## Commands

```bash
# Shell access
docker exec -it laravel-server bash

# Logs
docker-compose logs -f

# Stop
docker-compose down

# Stop & remove volumes
docker-compose down -v
```

## What's Included

- Ubuntu 24.04
- Apache 2.4
- PHP 8.4 (bcmath, curl, gd, intl, mbstring, mysql, opcache, redis, xml, zip)
- Composer
- Node.js 20
- MySQL 8.4

## License

MIT
