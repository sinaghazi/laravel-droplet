# Laravel Droplet

Minimal Docker environment for Laravel: **Apache + PHP 8.4 + MySQL + Redis + phpMyAdmin**

Deploy your Laravel app in seconds with a simple drag & drop upload.

## Quick Start

```bash
git clone https://github.com/sinaghazi/laravel-droplet.git
cd laravel-droplet
./deploy.sh
```

Open http://localhost → Upload your Laravel `.zip` → Done!

## Access URLs

| Service     | URL                    | Credentials          |
|-------------|------------------------|----------------------|
| Laravel App | http://localhost       | -                    |
| phpMyAdmin  | http://localhost:8080  | laravel / laravel    |
| MySQL       | localhost:3306         | root / root_password |
| Redis       | localhost:6379         | -                    |

## How It Works

1. **First visit**: Upload wizard appears
2. **Upload**: Drag & drop your Laravel `.zip` file (up to 200MB)
3. **Auto-setup**: Extracts files, sets correct ownership (`www-data`) and permissions
4. **Ready**: Laravel takes over, wizard is replaced

## Laravel .env Configuration

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=laravel

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PORT=6379
```

## Persistent Storage

All data is stored in Docker volumes:
- `www_data` - Laravel files (`/var/www/html`)
- `mysql_data` - Database files
- `redis_data` - Redis data

## Commands

```bash
# Shell access
docker exec -it laravel-server bash

# View logs
docker-compose logs -f

# Stop containers
docker-compose down

# Reset everything (removes all data)
docker-compose down -v
```

## Coolify / Self-Hosted Deployment

```yaml
services:
  laravel-droplet:
    image: sinaghazi/laravel-droplet:latest
    volumes:
      - www_data:/var/www/html
    expose:
      - "80"
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.4
    volumes:
      - mysql_data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: your_root_password
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: your_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pyour_root_password"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 30s
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

  phpmyadmin:
    image: phpmyadmin:latest
    environment:
      PMA_HOST: mysql
      UPLOAD_LIMIT: 200M
    expose:
      - "80"
    depends_on:
      mysql:
        condition: service_healthy
    restart: unless-stopped

volumes:
  www_data:
  mysql_data:
  redis_data:
```

## What's Included

- **Ubuntu 24.04** - Latest LTS
- **Apache 2.4** - With mod_rewrite enabled
- **PHP 8.4** - bcmath, curl, gd, intl, mbstring, mysql, opcache, redis, xml, zip
- **MySQL 8.4** - Database server
- **Redis 7** - Cache, sessions, queues
- **phpMyAdmin** - Database management UI
- **Composer** - PHP dependency manager
- **Node.js 22 LTS** - For frontend builds

## Build Your Own Image

```bash
./build-image.sh --username=yourusername --push
```

## License

MIT
