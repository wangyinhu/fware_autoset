#!/bin/bash

PROJECT_NAME="ippass"
LINUX_USERNAME="yale"

#root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

apt install nginx uwsgi uwsgi-plugin-python3 python3-pip inotify-tools

adduser www-data $LINUX_USERNAME

echo "setting up config..."
sed -i -e "s/ippass/$PROJECT_NAME/g" uwsgi.ini
sed -i -e "s/ippass/$PROJECT_NAME/g" reload.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" start.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" stop.sh

cp config_temp/ippass.conf /etc/nginx/sites-available/$PROJECT_NAME.conf

sed -i -e "s/ippass/$PROJECT_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME.conf
sed -i -e "s/LINUX_USERNAME/$LINUX_USERNAME/g" /etc/nginx/sites-available/$PROJECT_NAME.conf

ln -s /etc/nginx/sites-available/$PROJECT_NAME.conf /etc/nginx/sites-enabled/$PROJECT_NAME.conf

service nginx restart

pip3 install django

mkdir /var/log/uwsgi/

chown $LINUX_USERNAME:$LINUX_USERNAME /var/log/uwsgi/

echo "installing qbittorrent-nox"

apt install qbittorrent-nox

echo 'all done!'