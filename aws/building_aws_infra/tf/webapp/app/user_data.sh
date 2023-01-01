#!/bin/bash -ex
yum -y update
yum -y install httpd php mysql php-mysql

chkconfig httpd on
service httpd start

cd /var/www/html

S3_HOST=s3-us-west-2.amazonaws.com
APP_PATH=us-west-2-aws-training/awsu-spl/spl-13/scripts/app.tgz
wget https://${S3_HOST}/${APP_PATH}

tar xvfz app.tgz
chown apache:root /var/www/html/rds.conf.php
