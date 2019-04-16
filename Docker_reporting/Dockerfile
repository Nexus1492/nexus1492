FROM php:7.2-apache

RUN apt-get -y update && \
    apt-get -y install apt-utils

RUN export DEBIAN_FRONTEND="noninteractive" && \
    echo mysql-server mysql-server/root_password password pw | debconf-set-selections && \
    echo mysql-server mysql-server/root_password_again password pw | debconf-set-selections && \
    apt-get -y install mariadb-server mariadb-client


RUN docker-php-ext-install mysqli

COPY ./Docker_reporting/database /database
WORKDIR /database
RUN  /etc/init.d/mysql start && cat setup.sql database.sql setup_pt2.sql | mysql -uroot -ppw

COPY ./reporting_tool /var/www/html/
COPY ./Docker_reporting/start-everything /usr/local/bin/

CMD ["start-everything"]