FROM alpine:3.3
MAINTAINER Enrico Vecchio <enrico@cityglance.it>

ENV PHP_VERSION 7.0.3

RUN apk --update add wget nginx supervisor libpq


WORKDIR /tmp
COPY ./config-php-src/php-${PHP_VERSION}.tar.bz2  /tmp/php-${PHP_VERSION}.tar.bz2
RUN  tar -xvjf php-${PHP_VERSION}.tar.bz2

WORKDIR /tmp/php-${PHP_VERSION}

ENV BUILDPKGS "git autoconf tar make build-base postgresql-dev"
ENV RUNPKGS "curl libxpm libxpm-dev curl-dev gmp-dev libmcrypt-dev freetype-dev libwebp-dev libjpeg-turbo-dev libjpeg bzip2-dev openssl-dev krb5-dev libxml2 libxml2-dev libxslt libxslt-dev icu-dev"

RUN apk add --update ${BUILDPKGS} ${RUNPKGS}


RUN ./configure \
    --prefix=/usr/local \
    --enable-mbstring \
    --enable-zip \
    --enable-bcmath \
    --enable-pcntl \
    --enable-ftp \
    --enable-exif \
    --enable-calendar \
    --enable-sysvmsg \
    --enable-sysvsem \
    --enable-sysvshm \
    --enable-intl \
    --with-curl \
    --with-mcrypt \
    --with-iconv \
    --with-gmp \
    --with-gd \
    --with-jpeg-dir=/usr \
    --with-webp-dir=/usr \
    --with-png-dir=/usr \
    --with-zlib-dir=/usr \
    --with-xpm-dir=/usr \
    --with-freetype-dir=/usr \
    --with-pgsql=/usr/share/postgresql  \
    --with-pdo-pgsql=/usr/share/postgresql \
    --enable-gd-native-ttf \
    --enable-gd-jis-conv \
    --with-openssl \
    --with-zlib=/usr \
    --with-bz2=usr \
    --with-kerberos=shared,/usr/lib \
    --with-xsl \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --with-fpm-systemd=no && \

    # Build
    make install

RUN cp /usr/local/etc/php-fpm.conf.default /usr/local/etc/php-fpm.conf


RUN cp /tmp/php-${PHP_VERSION}/php.ini-production /usr/local/lib/php.ini && \
    rm -rf /tmp/php*

RUN adduser -h /var/www -s /bin/false -D -S -g 'User for running web applications' -G www-data  www-data


WORKDIR /tmp
RUN git clone https://github.com/phpredis/phpredis.git && \
    cd phpredis && \
    git checkout php7 && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    echo "extension=redis.so" >> /usr/local/lib/php.ini && \
    rm -rf tmp/phpredis

# Cleanup
RUN apk del --purge ${BUILDPKGS}





# Configure PHP-FPM
ADD ./config-nginx/www.conf /etc/php7/php-fpm.d/www.conf
ADD ./config-nginx/www.conf /usr/local/etc/php-fpm.d/*.conf


# Nginx configuration (see: http://nls.io/optimize-nginx-and-php-fpm-max_children/)
ADD ./config-nginx/nginx.conf /etc/nginx/nginx.conf


# Nginx host configuration
RUN mkdir /etc/nginx/sites-enabled
ADD  ./config-nginx/cg_site_available.conf                /etc/nginx/sites-available/
RUN  mv /etc/nginx/sites-available/cg_site_available.conf /etc/nginx/sites-available/default
RUN  cp /etc/nginx/sites-available/default                /etc/nginx/sites-enabled/default

# Configure supervisord
COPY ./config-supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


RUN mkdir -p /var/www/
RUN mkdir -p /var/www/web

RUN echo "<?php phpinfo() ?>" >> /var/www/web/info.php
RUN chmod 777 /var/www/web/info.php


EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
