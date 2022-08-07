## Small trick to get composer binary to other images
FROM composer:2 as composer


## The base image for building final images
FROM debian:bullseye-slim as base

# Install dependencies
RUN apt update && apt -y upgrade \
    && apt install -y --no-install-recommends \
        ca-certificates \
        git \
        php-cli \    
        php-xsl \    
        php-intl  \    
        php-mysqli  \    
        php-zip \ 
        curl \
        gnupg \
        zip \
    ; \
        mkdir /build

WORKDIR /build

# Get source clone. We'll use master branch.
RUN git clone https://github.com/emaijala/MLInvoice.git .; \
    git checkout master;

## Install dependencies
FROM base as build-php
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /build
ARG COMPOSER_ALLOW_SUPERUSER 1

RUN apt update && apt install zip; \
    composer install --no-dev;


## Base for final images
FROM base as final-codebase

# Make source directory and move build filest there.
RUN mkdir -p /usr/src/mlinvoice; \
    mv /build/* /usr/src/mlinvoice;

# Copy built composer stuff
COPY --from=build-php /build/vendor /usr/src/mlinvoice/vendor


# Final image to be used as base in other Dockerfiles. Please remember licensing.
FROM debian:bullseye-slim as final-base

RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
    libzip-dev \
    libc-client-dev \
    libicu-dev \
    libicu67 \
    libxml2-dev\
    libxml2 \
    libxslt1-dev \
    libxslt1.1 \
    libmcrypt-dev \
    libmcrypt4 \
    libzip-dev \
    libzip4 \
    mariadb-client \
    rsync \
    openssl \
    curl \
    ; \
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; 

# Ensure we are installing on a volume. Entrypoint will copy the code here
VOLUME /var/www/html

# Copy data for final image
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final-codebase --chown=www-data:www-data /usr/src/mlinvoice /usr/src/mlinvoice



## Build final FPM image
FROM php:fpm as final-php-fpm
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
    libzip-dev \
    libc-client-dev \
    libicu-dev \
    libicu67 \
    libxml2-dev\
    libxml2 \
    libxslt1-dev \
    libxslt1.1 \
    libmcrypt-dev \
    libmcrypt4 \
    libzip-dev \
    libzip4 \
    mariadb-client \
    rsync \
    openssl \
    curl \
    ; \
    #
    # Install php modules #
    docker-php-ext-install -j"$(nproc)" xsl; \
    docker-php-ext-install -j"$(nproc)" intl; \
    docker-php-ext-install -j"$(nproc)" mysqli; \
    pecl install mcrypt && docker-php-ext-enable mcrypt; \
    docker-php-ext-install -j"$(nproc)" zip; \
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
COPY --from=final-codebase --chown=www-data:www-data /usr/src/mlinvoice /usr/src/mlinvoice

RUN chmod a+x /docker-entrypoint.sh;

WORKDIR /var/www/html

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]



## Build final Apache 2 image
FROM php:apache as final-php-apache2
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
    libzip-dev \
    libc-client-dev \
    libicu-dev \
    libicu67 \
    libxml2-dev\
    libxml2 \
    libxslt1-dev \
    libxslt1.1 \
    libmcrypt-dev \
    libmcrypt4 \
    libzip-dev \
    libzip4 \
    mariadb-client \
    rsync \
    openssl \
    curl \
    ; \
    #
    # Install php modules #
    docker-php-ext-install -j"$(nproc)" xsl; \
    docker-php-ext-install -j"$(nproc)" intl; \
    docker-php-ext-install -j"$(nproc)" mysqli; \
    pecl install mcrypt && docker-php-ext-enable mcrypt; \
    docker-php-ext-install -j"$(nproc)" zip; \
    #
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    #
    # Modify settings #
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini";
# Make install dir and separate directory for configs. Entrypoint will link them.

# Ensure we are installing on a volume
VOLUME /var/www/html

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final-codebase --chown=www-data:www-data /usr/src/mlinvoice /usr/src/mlinvoice

RUN chmod a+x /docker-entrypoint.sh;

WORKDIR /var/www/html

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apache2-foreground"]