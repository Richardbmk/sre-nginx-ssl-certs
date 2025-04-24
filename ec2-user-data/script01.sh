#!/bin/bash

apt-get update -y
apt-get install apache2 -y

echo "This setup works you try now with something difficult!!" > /var/www/html/index.html

systemctl start apache2