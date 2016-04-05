FROM phusion/baseimage

ENV DEBIAN_FRONTEND noninteractive
ENV HOME="/root"
ENV TERM=xterm
ENV LANG=en_GB.UTF-8
ENV LANGUAGE=en_GB:en
ENV LC_ALL=en_GB.UTF-8
ENV ASTERISKUSER asterisk
ENV ASTERISK_DB_PW Password
ENV ASTERISKVER 13.8.0
ENV FREEPBXVER 12.0.43

EXPOSE 80

CMD ["/sbin/my_init"]

COPY start-apache2.sh /etc/service/apache2/run
COPY start-mysqld.sh /etc/service/mysqld/run
COPY start-asterisk.sh /etc/service/asterisk/run
COPY start-amportal.sh /etc/my_init.d/10_amportal.sh
COPY start-fail2ban.sh /etc/my_init.d/20_fail2ban.sh
COPY source/libzmq /usr/src 
COPY source/libsodium /usr/src 
COPY source/czmq /usr/src 

RUN chmod +x /etc/service/apache2/run && \
    chmod +x /etc/service/mysqld/run && \
    chmod +x /etc/service/asterisk/run && \
    chmod +x /etc/my_init.d/10_amportal.sh && \
    chmod +x /etc/my_init.d/20_fail2ban.sh

RUN sed -i 's/archive.ubuntu.com/mirrors.digitalocean.com/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        apache2 \
        automake \
        bison \
        build-essential \
        curl \
        fail2ban \
        flex \
        libasound2-dev \
        libcurl4-openssl-dev \
        libical-dev \
        libmyodbc \
        libmysqlclient-dev \
        libncurses5-dev \
        libneon27-dev \
        libnewt-dev \
        libogg-dev \
        libspandsp-dev \
        libsrtp0-dev \
        libssl-dev \
        libsqlite3-dev \
        libtool \
        libvorbis-dev \
        libxml2-dev \
        mpg123 \
        mysql-client \
        mysql-server \
        php5 \
        php5-cli \
        php5-curl \
        php-db \
        php5-gd \
        php5-mysql \
        php-pear \
        pkg-config \
        sox\
        sqlite3 \
        autoconf \
        subversion \
        unixodbc-dev \
        uuid \
        uuid-dev \
        libtool \
        pkg-config \
        build-essential \
        autoconf \
        automake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mv /etc/fail2ban/filter.d/asterisk.conf /etc/fail2ban/filter.d/asterisk.conf.org && \
    mv /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.org

COPY conf/fail2ban/asterisk.conf /etc/fail2ban/filter.d/asterisk.conf
COPY conf/fail2ban/jail.conf /etc/fail2ban/jail.conf

COPY conf/my-small.cnf /etc/mysql/my.cnf
COPY conf/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

RUN pear uninstall db && \
    pear install db-1.7.14

COPY tarfiles/pjproject-2.3.tar.bz2 /usr/src/pjproject.tar.bz2
WORKDIR /usr/src
RUN mkdir pjproject && \
    tar -xf pjproject.tar.bz2 -C pjproject --strip-components=1 && \
    rm pjproject.tar.bz2 && \
    cd pjproject && \
    ./configure --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr && \
    make dep && \
    make && \
    make install && \
    rm -r /usr/src/pjproject

COPY tarfiles/jansson-2.7.tar.gz /usr/src/jansson-2.7.tar.gz
WORKDIR /usr/src
RUN mkdir jansson && \
    tar -xzf jansson-2.7.tar.gz -C jansson --strip-components=1 && \
    rm jansson-2.7.tar.gz && \
    cd jansson && \
    autoreconf -i && \
    ./configure && \
    make && \
    make install && \
    rm -r /usr/src/jansson

COPY tarfiles/asterisk-13-current.tar.gz /usr/src/asterisk.tar.gz
WORKDIR /usr/src
RUN mkdir asterisk && \
    tar -xzf /usr/src/asterisk.tar.gz -C /usr/src/asterisk --strip-components=1 && \
    rm asterisk.tar.gz && \
    cd asterisk && \
    ./configure && \
    contrib/scripts/get_mp3_source.sh && \
    make menuselect.makeopts && \
    menuselect/menuselect --enable chan_sip menuselect.makeopts && \
    sed -i "s/BUILD_NATIVE//" menuselect.makeopts && \
    make && \
    make install && \
    make config && \
    ldconfig && \
    rm -r /usr/src/asterisk

COPY tarfiles/asterisk-extra-sounds-en-g722-current.tar.gz /var/lib/asterisk/sounds/asterisk-extra-sounds-en-g722-current.tar.gz
COPY tarfiles/asterisk-extra-sounds-en-wav-current.tar.gz /var/lib/asterisk/sounds/asterisk-extra-sounds-en-wav-current.tar.gz
WORKDIR /var/lib/asterisk/sounds
RUN tar -xzf asterisk-extra-sounds-en-wav-current.tar.gz && \
    rm -f asterisk-extra-sounds-en-wav-current.tar.gz && \
    tar -xzf asterisk-extra-sounds-en-g722-current.tar.gz && \
    rm -f asterisk-extra-sounds-en-g722-current.tar.gz

RUN useradd -m $ASTERISKUSER && \
    chown $ASTERISKUSER. /var/run/asterisk && \ 
    chown -R $ASTERISKUSER. /etc/asterisk && \
    chown -R $ASTERISKUSER. /var/lib/asterisk && \
    chown -R $ASTERISKUSER. /var/log/asterisk && \
    chown -R $ASTERISKUSER. /var/spool/asterisk && \
    chown -R $ASTERISKUSER. /usr/lib/asterisk && \
    chown -R $ASTERISKUSER. /var/www/ && \
    chown -R $ASTERISKUSER. /var/www/* && \
    rm -rf /var/www/html

RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php5/apache2/php.ini && \
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig && \
    sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

RUN /etc/init.d/mysql start && \
    mysqladmin -u root create asterisk && \
    mysqladmin -u root create asteriskcdrdb && \
    mysql -u root -e "GRANT ALL PRIVILEGES ON asterisk.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" && \
    mysql -u root -e "GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" && \
    mysql -u root -e "flush privileges;"

COPY tarfiles/freepbx-12.0.43.tgz /usr/src/freepbx-12.0.43.tgz
WORKDIR /usr/src
RUN tar xfz freepbx-$FREEPBXVER.tgz && \
    rm freepbx-$FREEPBXVER.tgz && \
    cd /usr/src/freepbx && \
    /etc/init.d/mysql start && \
    /etc/init.d/apache2 start && \
    /usr/sbin/asterisk && \ 
    ./install_amp --installdb --username=$ASTERISKUSER --password=$ASTERISK_DB_PW && \
    amportal chown && \
    amportal a ma upgrade framework && \
    amportal a ma upgradeall && \
    amportal chown && \
    amportal a reload && \
    amportal a ma refreshsignatures && \
    amportal chown && \
    mysql -u$ASTERISKUSER -p$ASTERISK_DB_PW asterisk -e "INSERT into logfile_logfiles \
        (name, debug, dtmf, error, fax, notice, verbose, warning, security) \
        VALUES ('fail2ban', 'off', 'off', 'on', 'off', 'on', 'off', 'on', 'on');" && \
    amportal a r && \
    ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3 && \
    rm -r /usr/src/freepbx

COPY conf/cdr/odbc.ini /etc/odbc.ini
COPY conf/cdr/odbcinst.ini /etc/odbcinst.ini
COPY conf/cdr/cdr_adaptive_odbc.conf /etc/asterisk/cdr_adaptive_odbc.conf
RUN chown asterisk:asterisk /etc/asterisk/cdr_adaptive_odbc.conf && \
    chmod 775 /etc/asterisk/cdr_adaptive_odbc.conf

WORKDIR /
