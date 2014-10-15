#!/bin/bash

cat << 'EOF' > /etc/yum/repos.d/mariadb
# MariaDB 10.1 CentOS repository list - created 2014-10-14 22:29 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
yum check-update
yum upgrade -y
yum install -y git mariadb
