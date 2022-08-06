FROM composer:2 as composer

FROM debian:bullseye-slim as base
RUN apt update && apt upgrade \
    && apt install -y --no-install-recommends \
        git \
        php-cli \    
        php-xsl \    
        php-intl  \    
        php-mysqli  \    
        php-mcrypt  \    
        php-zip \ 
        curl \
        git \
        gnupg \
        ; \
        mkdir /build

WORKDIR /build

RUN git clone https://github.com/emaijala/MLInvoice.git .; \
    git checkout master;

FROM base as build-php
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /build
ARG COMPOSER_ALLOW_SUPERUSER 1

RUN composer install --no-dev;


# Base for final images
FROM base as final-codebase
RUN mkdir -p /usr/src/mlinvoice; \
    mv /build/* /usr/src/mlinvoice;
COPY --from=build-php /build/vendor /usr/src/mlinvoice/vendor

# Development image
FROM debian:bullseye-slim as final-base

RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libc-client-dev \
    libkrb5-dev \
    rsync \
    openssl \
    curl \
    ; \
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    #
    # Modify settings #
    #
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini";

# Ensure we are installing on a volume. Entrypoint will copy the code here
VOLUME /var/www/html

# Copy data for final image
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final-codebase --chown=www-data:www-data /usr/src/mlinvoice /usr/src/mlinvoice



# FPM image
FROM php:fpm as final-php-fpm
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libc-client-dev \
    libkrb5-dev \
    rsync \
    openssl \
    curl \
    ; \
    #
    # Install php modules #
    docker-php-ext-install -j"$(nproc)" xsl intl mysqli mcrypt zip; \
    #
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    #
    # Modify settings #
    #
    # Use uid and gid of www-data used in nginx image
    usermod -u 101 www-data && groupmod -g 101 www-data; \
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini";
    # Make install dir and separate directory for configs. Entrypoint will link them.

# Ensure we are installing on a volume
VOLUME /var/www/html

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final --chown=www-data:www-data /final /usr/src/mlinvoice
COPY --chown=www-data:www-data config_si.php /tmp

RUN chmod a+x /docker-entrypoint.sh;

WORKDIR /var/www/html

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]
