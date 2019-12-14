1. run /setup/setup.sh as root
2. run /install.sh as root
3. run python3 ./manage.py makemigrations
4. run python3 ./manage.py migrate
5. run python3 ./manage.py createsuperuser
6. delete /etc/nginx/site-enabled/default as root
7. run /start.sh as user
8. run qbittorrent -d

