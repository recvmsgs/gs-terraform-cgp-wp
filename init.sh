#!/usr/bin/bash

apt update
apt install -y apache2 \
            ghostscript \
            libapache2-mod-php \
            php \
            php-bcmath \
            php-curl \
            php-imagick \
            php-intl \
            php-json \
            php-mbstring \
            php-mysql \
            php-xml \
            php-zip

mkdir -p /srv/www
sudo chown www-data: /srv/www
curl --silent https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www
find /srv/www/ -type d -exec chmod 755 {} \;
find /srv/www/ -type f -exec chmod 644 {} \;
cat << EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
  DocumentRoot /srv/www/wordpress
  <Directory /srv/www/wordpress>
      Options FollowSymLinks
      Require all granted
      DirectoryIndex index.php
      Order allow,deny
      Allow from all
  </Directory>
  <Directory /srv/www/wordpress/wp-content>
      Options FollowSymLinks
      Order allow,deny
      Allow from all
  </Directory>
</VirtualHost>
EOF
a2enmod rewrite
systemctl reload apache2
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php

sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/${DB_USERNAME}/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/${DB_PASSWORD}/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/localhost/${DB_HOST}/' /srv/www/wordpress/wp-config.php

systemctl restart apache2

