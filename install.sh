#!/bin/bash

PROJECT_NAME="ippass"
LUNM="yale"

#root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must run as root"
   exit 1
fi

apt install nginx uwsgi uwsgi-plugin-python3 python3-pip inotify-tools apache2-utils

adduser www-data $LUNM

echo "setting up config..."
sed -i -e "s/ippass/$PROJECT_NAME/g" uwsgi.ini
sed -i -e "s/ippass/$PROJECT_NAME/g" reload.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" start.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" stop.sh

cp setup/ippass.conf /etc/nginx/sites-available/$PROJECT_NAME.conf

sed -i -e "s/ippass/$PROJECT_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME.conf
sed -i -e "s/LUNM/$LUNM/g" /etc/nginx/sites-available/$PROJECT_NAME.conf

ln -s /etc/nginx/sites-available/$PROJECT_NAME.conf /etc/nginx/sites-enabled/$PROJECT_NAME.conf

cd /home/$LUNM || exit 1

htpasswd -c nginx_pass $LUNM

service nginx restart

pip3 install django

mkdir /var/log/uwsgi/

chown $LUNM:$LUNM /var/log/uwsgi/

echo "installing qbittorrent-nox"

apt install qbittorrent-nox

echo 'all done!'