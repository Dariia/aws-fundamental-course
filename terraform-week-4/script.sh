#!/bin/bash
sudo yum update -y
sudo yum install httpd -y
sudo chkconfig httpd on
sudo service httpd start
echo "<h1>My web server public</h1>" > /var/www/html/index.html
