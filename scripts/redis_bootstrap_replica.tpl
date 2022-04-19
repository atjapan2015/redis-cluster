#!/bin/bash
set -x
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/tflog.out 2>&1

EXTERNAL_IP=$(curl -s -m 10 http://whatismyip.akamai.com/)
REDIS_CONFIG_FILE=/etc/redis.conf
SENTINEL_CONFIG_FILE=/etc/sentinel.conf

# Setup firewall rules
firewall-offline-cmd --zone=public --add-port=${redis_port1}/tcp
firewall-offline-cmd --zone=public --add-port=${redis_port2}/tcp
firewall-offline-cmd --zone=public --add-port=${sentinel_port}/tcp
firewall-offline-cmd --zone=public --add-port=9121/tcp
systemctl restart firewalld

# Install wget and gcc
yum install -y wget gcc

# Download and compile Redis
wget http://download.redis.io/releases/redis-${redis_version}.tar.gz
tar xvzf redis-${redis_version}.tar.gz
cd redis-${redis_version}
make install

mkdir /redis_data
mkdir -p /var/log/redis/

# Configure Redis
cat << EOF > $REDIS_CONFIG_FILE
port ${redis_port1}
dir /redis_data
pidfile /var/run/redis/redis.pid
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-slave-validity-factor 0
cluster-announce-ip $EXTERNAL_IP
cluster-migration-barrier 2
appendonly yes
requirepass ${redis_password}
masterauth ${redis_password}
protected-mode yes
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
loglevel notice
logfile /var/log/redis/redis.log
databases 16
always-show-logo yes
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-disable-tcp-nodelay no
replica-priority 100
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
EOF

cat << EOF > /etc/systemd/system/redis.service
[Unit]
Description=Redis

[Service]
User=root
ExecStart=/usr/local/bin/redis-server /etc/redis.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable redis.service

# Install Redis Exporter
useradd --no-create-home --shell /bin/false redis-exporter
wget https://github.com/oliver006/redis_exporter/releases/download/v1.37.0/redis_exporter-v1.37.0.linux-amd64.tar.gz
tar xvfz redis_exporter-v1.37.0.linux-amd64.tar.gz
chmod +x redis_exporter-v1.37.0.linux-amd64/redis_exporter
mv redis_exporter-v1.37.0.linux-amd64/redis_exporter /usr/local/bin/redis_exporter
cat << EOF > /etc/systemd/system/redis-exporter.service
[Unit]
Description=Redis Exporter

[Service]
User=redis-exporter
ExecStart=/usr/local/bin/redis_exporter -redis.addr redis://localhost:6379 -redis.password ${redis_password}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable redis-exporter.service
systemctl start redis-exporter.service

sleep 30