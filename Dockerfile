# phpMatsuri ハンズオン用 app イメージ
# PHP + Composer + Node.js を 1 コンテナに同梱する
# (Wayfinder の Vite プラグインが php artisan を呼ぶため、PHP と Node を同居させる)

FROM composer:2.11.1 AS composer
FROM node:26.13.0-trixie-slim AS node

FROM php:8.5.12-cli-trixie

ARG HOST_UID=1000
ARG HOST_GID=1000
ARG LARAVEL_INSTALLER_VERSION=5.32.0

# OS パッケージ + PHP 拡張
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git unzip libicu-dev libzip-dev \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql intl zip bcmath pcntl \
    && apt-get purge -y --auto-remove libicu-dev libzip-dev \
    && apt-get install -y --no-install-recommends libicu76 libzip5 \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# Node.js / npm / npx
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# ホスト (Mac) と同じ UID/GID の一般ユーザーで実行し、生成ファイルの所有者ずれを防ぐ
RUN if ! getent group "${HOST_GID}" >/dev/null; then groupadd -g "${HOST_GID}" dev; fi \
    && useradd -m -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash dev \
    && mkdir -p /var/www/html /home/dev/.npm /home/dev/.composer/cache \
    && chown "${HOST_UID}:${HOST_GID}" /var/www/html \
    && chown -R "${HOST_UID}:${HOST_GID}" /home/dev/.npm /home/dev/.composer

USER dev
ENV COMPOSER_HOME=/home/dev/.composer
ENV PATH="/home/dev/.composer/vendor/bin:${PATH}"

# Laravel インストーラ
RUN composer global require "laravel/installer:${LARAVEL_INSTALLER_VERSION}" \
    && composer clear-cache

WORKDIR /var/www/html

EXPOSE 8000 5173
CMD ["sleep", "infinity"]
