#!/bin/sh
sudo yum update
sudo yum install -y apache
sudo systemctl httpd start

