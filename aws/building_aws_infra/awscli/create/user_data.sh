#!/bin/bash -ex
yum -y update
yum -y install httpd php mysql php-mysql

chkconfig httpd on
service httpd start

cd /var/www/html

wget https://us-west-2-aws-training.s3.amazonaws.com/courses/spl-13/v4.2.25.prod-d1c66ef6/scripts/app.tgz

tar xvfz app.tgz
chown apache:root /var/www/html/rds.conf.php
