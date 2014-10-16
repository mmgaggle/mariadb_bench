#!/bin/bash

# Fix DNS resolution
cat << 'EOF' > resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
sudo mv resolv.conf /etc/resolv.conf

sudo yum check-update

# Upgrade base packages
sudo yum upgrade -y

# Install build tools
sudo yum install -y screen git bzr gcc gcc-c++ autoconf automake make libtool \
  zlib zlib-devel openssl-devel mysql-devel mysql-libs

# Build sysbench
bzr branch lp:sysbench
cd sysbench
./autogen.sh
./configure --without-drizzle \
  --with-mysql-libs=/usr/lib64/mysql \
  --with-mysql-includes=/usr/include/mysql
make
sudo make install

# Configure MariaDB repo
cat << 'EOF' > mariadb.repo
# MariaDB 10.1 CentOS repository list - created 2014-10-14 22:29 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
sudo mv mariadb.repo /etc/yum.repos.d/
sudo rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
sudo yum check-update

# Install MariaDB packages
sleep 2
sudo yum install -y MariaDB-server MariaDB-client MariaDB-devel

# Create MariaDB configuration
cat << 'EOF' > server.cnf
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#

# this is read by the standalone daemon and embedded servers
[server]
table_open_cache = 512
thread_cache = 512
query_cache_size = 0
query_cache_type = 0
#innodb_data_home_dir = /data/mysql/
#innodb_data_file_path = ibdata1:128M:autoextend
#innodb_log_group_home_dir = /data/mysql/
innodb_buffer_pool_size = 12800M
innodb_additional_mem_pool_size = 32M
innodb_log_file_size = 256M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50
innodb_doublewrite = 0
innodb_flush_method = O_DIRECT
innodb_thread_concurrency = 0
innodb_max_dirty_pages_pct = 80


# this is only for the mysqld standalone daemon
[mysqld]

# this is only for embedded server
[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# This group is only read by MariaDB-10.1 servers.
# If you use the same .cnf file for MariaDB of different versions,
# use this group for options that older servers don't understand
[mariadb-10.1]

EOF
sudo mv server.cnf /etc/my.cnf.d

# Start MariaDB
sudo service mysql start

# Create benchmark
cat << 'EOF' > bench.sh
#!/bin/bash

TEST_DIR=${HOME}/sysbench/sysbench/tests/db
STAMP=$(date +%m%d%Y-%H%M)

for TEST in insert.lua oltp.lua oltp_simple.lua;do
  for NUM_THREADS in 1 4 8 16 32 64;do
    yes | sudo mysqladmin -uroot drop sbtest
    sudo mysqladmin -uroot create sbtest
    /usr/local/bin/sysbench \
      --test=${TEST_DIR}/${TEST} \
      --oltp-table-size=2000000 \
      --max-time=300 \
      --max-requests=0 \
      --mysql-table-engine=InnoDB \
      --mysql-user=root \
      --mysql-engine-trx=yes \
      --num-threads=$NUM_THREADS \
      prepare

    /usr/local/bin/sysbench \
      --test=${TEST_DIR}/${TEST} \
      --oltp-table-size=2000000 \
      --max-time=300 \
      --max-requests=0 \
      --mysql-table-engine=InnoDB \
      --mysql-user=root \
      --mysql-engine-trx=yes \
      --num-threads=$NUM_THREADS \
      run 2>&1| tee ${STAMP}-${TEST}-${NUM_THREADS}_threads.out
  done
done
EOF

# Run benchmark in screen
#screen -US bench exec "bash bench.sh"
