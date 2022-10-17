# Copyright 2022 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

FROM marketplace.gcr.io/google/php7-fpm:7.4

ENV DEBUG_DOCKER_ENTRYPOINT false

ENV MAGENTO_ADMIN_EMAIL noreply@admin.example
ENV MAGENTO_HOSTNAME localhost
ENV MAGENTO_RUN_MODE production
ENV ENABLE_CRONJOBS true

ENV MAGENTO_SHA256 641479a30ccce81618f38294e98af4aec1e870de066f04f6c7038125a0948bfb
ENV MAGENTO_VERSION 2.4.5
ENV C2D_RELEASE 2.4.5

ENV MAGENTO_MYSQL_DB magento
ENV MAGENTO_MYSQL_HOST localhost
ENV MAGENTO_MYSQL_PORT 3306

ENV MAGENTO_REDIS_HOST localhost
ENV MAGENTO_REDIS_PORT 6379

ENV SODIUM_SHA256 b7292dd1da67a049c8e78415cd498ec138d194cfdb302e716b08d26b80fecc10
ENV SODIUM_VERSION 1.0.18

ENV COMPOSER_SHA256 1f210b9037fcf82670d75892dfc44400f13fe9ada7af9e787f93e50e3b764111
ENV COMPOSER_VERSION 1.9.1

ENV NGINX_VERSION 1.18.0

ENV PHP_MEMORY_LIMIT 2G
ENV PHP_UPLOAD_SIZE 64M

# Install dependencies
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
    apt-utils \
    cron \
    gettext-base \
    git \
    jq \
    libbz2-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libfreetype6-dev \
    libgeoip-dev \
    python \
    wget \
    libgmp-dev \
    libmagickwand-dev \
    libmagickcore-dev \
    libc-client-dev \
    libkrb5-dev \
    libicu-dev \
    libldap2-dev \
    libpspell-dev \
    librecode0 \
    librecode-dev \
    libtidy-dev \
    libxslt1-dev \
    libyaml-dev \
    libzip-dev \
    mariadb-client \
    nginx=${NGINX_VERSION}* \
    procps \
    pwgen \
    sudo \
    supervisor \
    unzip \
    zip \
  && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure opcache --enable-opcache

RUN docker-php-ext-install -j$(nproc) \
  bcmath \
  bz2 \
  calendar \
  exif \
  gd \
  gettext \
  gmp \
  imap \
  intl \
  ldap \
  mysqli \
  opcache \
  pdo_mysql \
  pspell \
  shmop \
  soap \
  sockets \
  sysvmsg \
  sysvsem \
  sysvshm \
  tidy \
  xsl \
  zip \
  pcntl

RUN pecl install -o -f \
  xmlrpc-1.0.0RC3 \
  mailparse \
  msgpack \
  oauth \
  raphf \
  redis \
  yaml

# Install Sodium, a Magento requirement after version 2.3.2
RUN rm -f /usr/local/etc/php/conf.d/*sodium.ini \
  && rm -f /usr/local/lib/php/extensions/*/*sodium.so \
  && apt-get remove libsodium* -y  \
  && mkdir -p /tmp/libsodium  \
  && curl -sL https://github.com/jedisct1/libsodium/archive/1.0.18-RELEASE.tar.gz | tar xzf - -C  /tmp/libsodium \
  && cd /tmp/libsodium/libsodium-1.0.18-RELEASE/ \
  && ./configure \
  && make && make check \
  && make install  \
  && cd / \
  && rm -rf /tmp/libsodium  \
  && pecl install -o -f libsodium

# Enable PHP extensions
RUN docker-php-ext-enable \
  bcmath \
  bz2 \
  calendar \
  exif \
  gd \
  gettext \
  gmp \
  imap \
  intl \
  ldap \
  mailparse \
  msgpack \
  mysqli \
  oauth \
  opcache \
  pdo_mysql \
  pspell \
  raphf \
  redis \
  shmop \
  soap \
  sockets \
  sodium \
  sysvmsg \
  sysvsem \
  sysvshm \
  tidy \
  xsl \
  yaml \
  zip \
  pcntl

# Copy configuration files and scripts
COPY etc/php-fpm.ini /usr/local/etc/php/conf.d/zz-magento.ini
COPY etc/php-fpm.conf /usr/local/etc/
COPY etc/nginx-magento.conf /etc/nginx/sites-enabled/magento
COPY etc/metrics.conf /etc/nginx/sites-enabled/metrics
COPY etc/supervisord.conf /etc/supervisor/conf.d/supervisor.conf

# Copy script files
ADD scripts/*.sh /usr/local/bin/
COPY scripts/inject_hostname.py /scripts/inject_hostname.py
COPY scripts/inc/hostname_fix /scripts/inc/hostname_fix
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh \
    && chmod +x /usr/local/bin/*.sh

# Install Composer (PHP package manager)
RUN set -e \
    && cd /usr/local/bin \
    && curl -o composer.phar "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar" \
    && echo "${COMPOSER_SHA256} composer.phar" | sha256sum -c - \
    && chmod +x composer.phar

VOLUME /app

WORKDIR /magento

# Download and install Magento libraries via Composer
RUN curl -L -o magento.tar.gz https://api.github.com/repos/magento/magento2/tarball/${MAGENTO_VERSION} \
   && test "$(sha256sum magento.tar.gz | awk {'print $1'})" = ${MAGENTO_SHA256} \
   && tar -xf magento.tar.gz -C /magento --strip-components=1 \
   && rm -f magento.tar.gz \
   && composer.phar install

WORKDIR /app

EXPOSE 80 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisor.conf"]
