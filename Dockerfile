FROM ubuntu:20.04

#Args for use in construction of the container
#Change the LOCAL_UID to that of your user that owns the git repo files
ARG LOCAL_UID=1000
ARG APACHE_VERSION=2.4.51
ARG PHP_VERSION=7.4.27
ARG FFMPEG_VERSION=4.3.3
ENV DEBIAN_FRONTEND=noninteractive

#Apache
RUN apt -qq update && apt-get -qq install curl wget gnupg && apt-get -qq install wget vim libreadline-dev libssl-dev libpcre3-dev libexpat1-dev build-essential bison zlib1g-dev libxss1 libappindicator1 libindicator7 sudo tzdata unzip less

RUN wget https://ai.galib.uga.edu/files/httpd-$APACHE_VERSION-w-apr.tar.gz && tar xzf httpd-$APACHE_VERSION-w-apr.tar.gz && cd httpd-$APACHE_VERSION && ./configure  '--prefix=/app/apache2' '--with-apxs2=/app/apache2/bin/apxs' '--with-mysqli' '--with-pear' '--with-xsl' '--with-pspell' '--enable-ssl' '--with-gettext' '--with-gd' '--enable-mbstring' '--with-mcrypt' '--enable-soap' '--enable-sockets' '--with-libdir=/lib/i386-linux-gnu' '--with-jpeg-dir=/usr' '--with-png-dir=/usr' '--with-curl' '--with-pdo-mysql' '--enable-so' '--with-included-apr' && make -j$(nproc) && make install && cd ..&& rm -rf httpd-$APACHE_VERSION*

ENV PATH /app/apache2/bin:$PATH

RUN sed -i "s/\/snap\/bin/\/snap\/bin:\/app\/apache2\/bin/" /etc/sudoers

#PHP
RUN apt-get -qq install libcurl4-gnutls-dev pkg-config libpng-dev libonig-dev libsqlite3-dev libxml2-dev libzip-dev libmemcached-dev memcached && wget https://ai.galib.uga.edu/files/php-$PHP_VERSION.tar.gz && tar xzf php-$PHP_VERSION.tar.gz && cd php-$PHP_VERSION && './configure'  '--prefix=/usr/local' '--with-apxs2=/app/apache2/bin/apxs' '--with-mysqli' '--enable-mbstring' '--with-pdo-mysql' '--with-openssl' '--with-zlib' '--enable-gd' '--enable-opcache' '--with-curl' '--enable-exif' '--with-zip' && make -j$(nproc) && make install && cp php.ini-production /usr/local/lib/php.ini && cd .. && rm -rf php-$PHP_VERSION*

RUN apt-get -qq install autoconf && wget https://pecl.php.net/get/memcached-3.1.5.tgz && tar xzf memcached-3.1.5.tgz && cd memcached-3.1.5 && phpize && ./configure && make && make install && echo "extension=memcached.so" >> /usr/local/lib/php.ini && cd .. && rm -rf memcached-3.1.5*

#Config changes for apache/php
RUN sed -i "s/DirectoryIndex index.html/DirectoryIndex index.html index.php/" /app/apache2/conf/httpd.conf && sed -i "s/#AddType application\/x-gzip .tgz/AddType application\/x-httpd-php .php/" /app/apache2/conf/httpd.conf && sed -i "s/memory_limit = 128M/memory_limit = 1G/" /usr/local/lib/php.ini && sed -i "s/post_max_size = 8M/post_max_size = 1032MB/" /usr/local/lib/php.ini && sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 1024M/" /usr/local/lib/php.ini && sed -i "s/display_errors = Off/display_errors = On/" /usr/local/lib/php.ini

#Composer
RUN curl --output /usr/local/bin/composer https://getcomposer.org/composer.phar     && chmod +x /usr/local/bin/composer

RUN echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf

#GraphicsMagick/Imagemagick/Mediainfo
RUN apt-get -qq install graphicsmagick imagemagick mediainfo

#FFMPEG
RUN apt-get install -qq autoconf automake build-essential cmake git-core libass-dev libfreetype6-dev libgnutls28-dev libsdl2-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev meson ninja-build pkg-config texinfo wget yasm zlib1g-dev nasm libx264-dev libx265-dev libnuma-dev libvpx-dev libfdk-aac-dev libmp3lame-dev libopus-dev libaom-dev && wget https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.gz && tar xzf ffmpeg-$FFMPEG_VERSION.tar.gz && cd ffmpeg-$FFMPEG_VERSION && ./configure --enable-gpl --enable-gnutls --enable-libaom --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-nonfree --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 && make -j$(nproc) && make install && cd .. && rm -rf ffmpeg-$FFMPEG_VERSION*

#GitLab runner
RUN adduser --uid $LOCAL_UID --gecos 'gitlab-runner user' --disabled-password gitlab-runner
COPY docker_templates/gitlab-runner /etc/sudoers.d/

#Prepare docroot
RUN rm -rf /app/apache2/htdocs 

#Copy startup script, setup file, and permissions script
COPY docker_templates/startup.sh /
COPY docker_templates/setup_ca_permissions.sh /usr/local/bin/
COPY docker_templates/setup.php.docker /app/apache2/htdocs/setup.php

USER gitlab-runner

#CMD ["/bin/bash"]
CMD ["./startup.sh"]
