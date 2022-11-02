#!/bin/bash

PROJECT_NAME="ippass"
LUNM=$(logname)

#root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must run as root"
   exit 1
fi

apt install nginx uwsgi uwsgi-plugin-python3 python3-pip python3-venv inotify-tools apache2-utils screen

adduser www-data $LUNM

echo "setting up config..."
sed -i -e "s/ippass/$PROJECT_NAME/g" uwsgi.ini
sed -i -e "s/LUNM/$LUNM/g" uwsgi.ini
sed -i -e "s/ippass/$PROJECT_NAME/g" reload.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" start.sh
sed -i -e "s/ippass/$PROJECT_NAME/g" stop.sh

cp setup/ippass.conf /etc/nginx/sites-available/$PROJECT_NAME.conf

sed -i -e "s/ippass/$PROJECT_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME.conf
sed -i -e "s/LUNM/$LUNM/g" /etc/nginx/sites-available/$PROJECT_NAME.conf

ln -s /etc/nginx/sites-available/$PROJECT_NAME.conf /etc/nginx/sites-enabled/$PROJECT_NAME.conf

cd /home/$LUNM || exit 1

mkdir Downloads

echo "creating nginx pass for user $LUNM"
htpasswd -c nginx_pass $LUNM

rm /etc/nginx/sites-enabled/default

service nginx restart

mkdir /var/log/uwsgi/

chown $LUNM:$LUNM /var/log/uwsgi/

cd /home/$LUNM/$PROJECT_NAME || exit 1

echo "setting up python venv..."

sudo -u $LUNM python3 -m venv venv

sudo -u $LUNM ./venv/bin/pip3 install django

sudo -u $LUNM ./venv/bin/python3 manage.py makemigrations

sudo -u $LUNM ./venv/bin/python3 manage.py migrate

sudo -u $LUNM ./venv/bin/python3 manage.py createsuperuser

sudo -u $LUNM uwsgi --ini uwsgi.ini

echo 'all done!'