set -e
unset HISTFILE
history -cw

#echo === Waiting for Cloud-Init ===
#timeout 180 /bin/bash -c 'until stat /var/lib/cloud/instance/boot-finished &>/dev/null; do echo waiting...; sleep 6; done'

echo === System Packages ===
sudo apt-get -qq update
sudo apt-get -y -qq install --no-install-recommends apt-transport-https apt-show-versions bash-completion logrotate ntp ntpdate htop vim wget curl dbus bmon nmon parted mawk wget curl sudo rsyslog ethtool unzip zip telnet tcpdump strace tar libyaml-0-2 lsb-base lsb-release xfsprogs sysfsutils openjdk-8-jdk-headless
sudo apt-get -y -qq --purge autoremove
sudo apt-get autoclean
sudo apt-get clean

echo === System Settings ===
echo 'dash dash/sh boolean false' | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive dash
sudo update-locale LC_CTYPE="${SYSTEM_LOCALE}.UTF-8"
echo 'export TZ=:/etc/localtime' | sudo tee /etc/profile.d/tz.sh > /dev/null
sudo update-alternatives --set editor /usr/bin/vim.basic

echo === Sysctl ===
sudo cp /tmp/50-zookeeper.conf /etc/sysctl.d/
sudo chown root:root /etc/sysctl.d/50-zookeeper.conf
sudo chmod 0644 /etc/sysctl.d/50-zookeeper.conf
sudo sysctl -p /etc/sysctl.d/50-zookeeper.conf

echo === Java ===
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java' | sudo tee /etc/profile > /dev/null

echo === Zookeeper ===
sudo groupadd -g ${ZOOKEEPER_UID} zookeeper
sudo useradd -m -u ${ZOOKEEPER_UID} -g ${ZOOKEEPER_UID} -c 'Apache Zookeeper' -s /bin/bash -d /srv/zookeeper zookeeper
curl -sL --retry 3 --insecure "https://archive.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/zookeeper-${ZOOKEEPER_VERSION}.tar.gz" | sudo tar xz --strip-components=1 -C /srv/zookeeper/
sudo mkdir -p /data/zookeeper
sudo mkdir -p /var/{log,run}/zookeeper
sudo ln -s /var/log/zookeeper /srv/zookeeper/logs
sudo ln -s /data/zookeeper /srv/zookeeper/data
sudo cp /srv/zookeeper/conf/zoo_sample.cfg /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e '/^dataDir/s/=.*/=\/data\/zookeeper/' /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e '/^clientPort/s/=.*/=2181/' /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e 's/# *maxClientCnxns/maxClientCnxns/;/^maxClientCnxns/s/=.*/=100/' /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e 's/# *autopurge.snapRetainCount/autopurge.snapRetainCount/;/^autopurge.snapRetainCount/s/=.*/=50/' /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e 's/# *autopurge.purgeInterval/autopurge.purgeInterval/;/^autopurge.purgeInterval/s/=.*/=3/' /srv/zookeeper/conf/zoo.cfg
sudo sed -i -r -e 's/# *log4j.appender.ROLLINGFILE.MaxFileSize/log4j.appender.ROLLINGFILE.MaxFileSize/;/^log4j.appender.ROLLINGFILE.MaxFileSize/s/=.*/=10MB/' /srv/zookeeper/conf/log4j.properties
sudo sed -i -r -e 's/# *log4j.appender.ROLLINGFILE.MaxBackupIndex/log4j.appender.ROLLINGFILE.MaxBackupIndex/;/^log4j.appender.ROLLINGFILE.MaxBackupIndex/s/=.*/=10/' /srv/zookeeper/conf/log4j.properties

cat <<- EOF | sudo tee /srv/zookeeper/conf/java.env
JVMFLAGS="$JVMFLAGS -Xmx$(/usr/bin/awk '/MemTotal/{m=$2*.20;print int(m)k}' /proc/meminfo)"
JMXLOCALONLY=false
JMXPORT=7199
JMXAUTH=false
JMXSSL=false
EOF

cat <<- EOF | sudo tee -a /srv/zookeeper/conf/zookeeper-env.sh
ZOO_LOG4J_PROP=INFO,ROLLINGFILE
ZOO_LOG_DIR=/var/log/zookeeper
ZOOPIDFILE=/var/run/zookeeper/zookeeper.pid
ZOOCFGDIR=/srv/zookeeper/conf
EOF


echo 1 | sudo tee /data/zookeeper/myid > /dev/null
sudo chown -R zookeeper:zookeeper /srv/zookeeper /data/zookeeper /var/log/zookeeper /var/run/zookeeper
sudo cp /tmp/zookeeper.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl disable zookeeper.service
sudo cp /tmp/zookeeper_config /usr/local/bin/
sudo chown root:staff /usr/local/bin/zookeeper_config
sudo chmod 0755 /usr/local/bin/zookeeper_config

echo === Extra System Settings ===
sudo sed -r -i -e 's/.*(GRUB_CMDLINE_LINUX_DEFAULT)=\"(.*)\"/\1=\"\2 elevator=deadline\"/' /etc/default/grub
sudo update-grub2
echo === System Cleanup ===
sudo rm -f /root/.bash_history
sudo rm -f /home/${SSH_USERNAME}/.bash_history
sudo rm -f /var/log/wtmp
sudo rm -f /var/log/btmp
sudo rm -rf /var/log/installer
sudo rm -rf /var/lib/cloud/instances
sudo rm -rf /tmp/* /var/tmp/* /tmp/.*-unix
sudo find /var/cache -type f -delete
sudo find /var/log -type f | while read f; do echo -n '' | sudo tee $f > /dev/null; done;
sudo find /var/lib/apt/lists -not -name lock -type f -delete
sudo sync

echo === All Done ===