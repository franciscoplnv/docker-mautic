FROM php:7.4-apache

LABEL vendor="Mautic"
LABEL maintainer="Franisco Piedras <francisco@lonuncavisto.com>"

# Instalamos las dependencias necesarias
RUN apt-get update && apt-get install --no-install-recommends -y \
    cron \
    curl \
    git \
    libc-client-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libkrb5-dev \
    libmcrypt-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libz-dev \
    libzip-dev \
    sudo \
    unzip \
    wget \
    zip \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/cron.daily/*

RUN pecl install mcrypt-1.0.4

RUN docker-php-ext-configure imap --with-imap --with-imap-ssl --with-kerberos \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd imap intl mbstring mysqli pdo_mysql zip opcache bcmath sockets exif \
    && docker-php-ext-enable imap intl mbstring mcrypt mysqli pdo_mysql zip opcache bcmath sockets exif

RUN a2enmod rewrite

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Definimos el directorio
VOLUME /var/www

# Definimos las versión de Mautic y la firma SHA1
ENV MAUTIC_VERSION 4.4.6
ENV MAUTIC_SHA1 4bbfd6e7f73aedfb298b58c31f4d8ff011052d7f

# Activamos los CRONS por defecto
ENV MAUTIC_RUN_CRON_JOBS true

# Desactivamos las migraciones por defecto
ENV MAUTIC_RUN_MIGRATIONS false

# Configuraciones por defecto
ENV MAUTIC_DB_USER root
ENV MAUTIC_DB_NAME mautic
ENV MAUTIC_DB_PORT 3306

# Configuración de propiedades de PHP
ENV PHP_INI_DATE_TIMEZONE='Europe/Madrid' \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_UPLOAD=128M \
    PHP_MAX_EXECUTION_TIME=300

# Requerimos mautic sin instalar
ENV COMPOSER_ALLOW_SUPERUSER true
RUN composer create-project mautic/recommended-project:^4 /var/www/html --no-install
WORKDIR /var/www/html
RUN composer config --no-plugins allow-plugins.composer/installers true
RUN composer config --no-plugins allow-plugins.symfony/flex true
RUN composer config --no-plugins allow-plugins.mautic/core-composer-scaffold  true
RUN composer config --no-plugins allow-plugins.mautic/core-project-message true
RUN composer require acquia/mc-cs-plugin-custom-objects

# Aplicamos los permisos necesarios
RUN chown -R www-data:www-data /var/www/html


# Copia el archivo de configuración de Apache para Mautic
COPY ./apache2.conf /etc/apache2/sites-available/000-default.conf


# Script de inicializacion
COPY common/docker-entrypoint.sh /entrypoint.sh
COPY common/makeconfig.php /makeconfig.php
COPY common/makedb.php /makedb.php
COPY common/mautic.crontab /etc/cron.d/mautic
RUN chmod 644 /etc/cron.d/mautic

# Aplicamos permisos
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

CMD ["apache2-foreground"]
