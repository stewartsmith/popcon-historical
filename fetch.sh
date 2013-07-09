#!/bin/bash

DATE=`date +%Y%m%d`

#wget http://popcon.debian.org/by_inst -O debian-$DATE
#wget http://popcon.debian.org/stable/by_inst -O debian-stable-$DATE
#wget http://popcon.ubuntu.com/by_inst -O ubuntu-$DATE

wget http://popcon.debian.org/all-popcon-results.gz -O debian-$DATE
wget http://popcon.debian.org/stable/stable-popcon-results.gz -O debian-stable-$DATE
wget http://popcon.ubuntu.com/all-popcon-results.txt.gz -O ubuntu-$DATE
