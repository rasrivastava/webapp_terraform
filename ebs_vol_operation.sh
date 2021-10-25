#!/bin/bash

sudo mkfs.ext4  /dev/xvdh
sudo mount  /dev/xvdh  /var/www/html
sudo rm -rf /var/www/html/*
sudo git clone https://github.com/rasrivastava/tf_test.git /var/www/html/
