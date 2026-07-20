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
# System Packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    curl \
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

RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    exif \
    gd \
    intl \
    opcache \
    pdo_pgsql \
    pgsql \
    zip

# Redis
RUN pecl install redis \
    && docker-php-ext-enable redis

# ------------------------------------------------------------
# PHP Configuration
# ------------------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-production" \
    "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

COPY . .

COPY --from=vendor /app/vendor ./vendor

RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    bootstrap/cache

RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache

RUN chmod -R 775 \
    storage \
    bootstrap/cache

RUN php artisan package:discover --ansi || true

EXPOSE 9000

CMD ["php-fpm"]
