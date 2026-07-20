# ============================================================
# Stage 1: Composer Dependencies
# ============================================================
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress \
    --no-scripts

COPY . .

RUN composer dump-autoload --optimize


# ============================================================
# Stage 2: Laravel PHP-FPM
# ============================================================
FROM php:8.4-fpm

# ------------------------------------------------------------
# System Dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    nginx \
    git \
    supervisor \
    curl \
    unzip \
    zip \
    libpq-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# PHP Extensions
# ------------------------------------------------------------
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

RUN docker-php-ext-install -j"$(nproc)" \
    bcmath \
    exif \
    gd \
    intl \
    opcache \
    pdo_pgsql \
    pgsql \
    zip

# ------------------------------------------------------------
# PHP Configuration
# ------------------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-production" \
    "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

# ------------------------------------------------------------
# Application
# ------------------------------------------------------------
COPY . .

COPY --from=vendor /app/vendor ./vendor

# ------------------------------------------------------------
# Laravel Permissions
# ------------------------------------------------------------
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# ------------------------------------------------------------
# Laravel Optimization
# ------------------------------------------------------------
RUN php artisan package:discover --ansi || true \
    && php artisan config:cache || true \
    && php artisan route:cache || true \
    && php artisan view:cache || true

EXPOSE 9000

CMD ["php-fpm"]
