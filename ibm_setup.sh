#! /bin/bash
echo "-- Configure and optimize the OS"
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local
echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag" >> /etc/rc.d/rc.local
# add tuned optimization https://www.cloudera.com/documentation/enterprise/6/6.2/topics/cdh_admin_performance.html
echo  "vm.swappiness = 1" >> /etc/sysctl.conf
sysctl vm.swappiness=1
timedatectl set-timezone UTC
# CDSW requires Centos 7.5, so we trick it to believe it is...
echo "CentOS Linux release 7.5.1810 (Core)" > /etc/redhat-release

echo "-- Install Java OpenJDK8 and other tools"
# IBM image doesn't have ntpd or chronyd installed
yum install -y java-1.8.0-openjdk-devel vim wget curl git bind-utils chrony

systemctl enable chronyd
systemctl start chronyd

TEMPLATE=$2
DOCKERDEVICE=$3


echo "-- Configure networking"
PUBLIC_IP=`curl https://api.ipify.org/`
PRIVATE_IP=`hostname -I | cut -d " " -f1`
# if /etc/hosts doesn't have entry "127.0.0.1 cloudera-edh-fresh-vsi.bluemix.net cloudera-edh-fresh-vsi",
# then hostname -f returns only "bluemix.net"
#hostnamectl set-hostname `hostname -f`
# need to erase local etc hosts file..
echo "127.0.0.1 localhost.localdomain localhost" > /etc/hosts
echo "127.0.0.1 localhost4.localdomain4 localhost4" >> /etc/hosts
echo "$PRIVATE_IP `hostname`" >> /etc/hosts
#sed -i "s/HOSTNAME=.*/HOSTNAME=`hostname`/" /etc/sysconfig/network
iptables-save > ~/firewall.rules
systemctl disable firewalld
systemctl stop firewalld
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config


echo "-- Install CM and MariaDB repo"
wget https://archive.cloudera.com/cm6/6.2.0/redhat7/yum/cloudera-manager.repo -P /etc/yum.repos.d/

## MariaDB 10.1
cat - >/etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum clean all
rm -rf /var/cache/yum/
yum repolist

yum install -y cloudera-manager-daemons cloudera-manager-agent cloudera-manager-server MariaDB-server MariaDB-client
cat mariadb.config > /etc/my.cnf


echo "--Enable and start MariaDB"
systemctl enable mariadb
systemctl start mariadb

echo "-- Install JDBC connector"
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz -P ~
tar zxf ~/mysql-connector-java-5.1.46.tar.gz -C ~
mkdir -p /usr/share/java/
cp ~/mysql-connector-java-5.1.46/mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar

echo "-- Create DBs required by CM"
mysql -u root < ~/OneNodeCDHCluster/create_db.sql

echo "-- Secure MariaDB"
mysql -u root < ~/OneNodeCDHCluster/secure_mariadb.sql

echo "-- Prepare CM database 'scm'"
/opt/cloudera/cm/schema/scm_prepare_database.sh mysql scm scm cloudera

echo "-- Install CSDs"
wget https://archive.cloudera.com/CFM/csd/1.0.0.0/NIFI-1.9.0.1.0.0.0-90.jar -P /opt/cloudera/csd/
wget https://archive.cloudera.com/CFM/csd/1.0.0.0/NIFICA-1.9.0.1.0.0.0-90.jar -P /opt/cloudera/csd/
wget https://archive.cloudera.com/CFM/csd/1.0.0.0/NIFIREGISTRY-0.3.0.1.0.0.0-90.jar -P /opt/cloudera/csd/
wget https://archive.cloudera.com/cdsw1/1.5.0/csd/CLOUDERA_DATA_SCIENCE_WORKBENCH-CDH6-1.5.0.jar -P /opt/cloudera/csd/

chown cloudera-scm:cloudera-scm /opt/cloudera/csd/*
chmod 644 /opt/cloudera/csd/*

echo "-- Install CEM Tarballs"
mkdir -p /opt/cloudera/cem
wget https://archive.cloudera.com/CEM/centos7/1.x/updates/1.0.0.0/CEM-1.0.0.0-centos7-tars-tarball.tar.gz -P /opt/cloudera/cem
tar xzf /opt/cloudera/cem/CEM-1.0.0.0-centos7-tars-tarball.tar.gz -C /opt/cloudera/cem
tar xzf /opt/cloudera/cem/CEM/centos7/1.0.0.0-54/tars/efm/efm-1.0.0.1.0.0.0-54-bin.tar.gz -C /opt/cloudera/cem
tar xzf /opt/cloudera/cem/CEM/centos7/1.0.0.0-54/tars/minifi/minifi-0.6.0.1.0.0.0-54-bin.tar.gz -C /opt/cloudera/cem
tar xzf /opt/cloudera/cem/CEM/centos7/1.0.0.0-54/tars/minifi/minifi-toolkit-0.6.0.1.0.0.0-54-bin.tar.gz -C /opt/cloudera/cem
rm -f /opt/cloudera/cem/CEM-1.0.0.0-centos7-tars-tarball.tar.gz
ln -s /opt/cloudera/cem/efm-1.0.0.1.0.0.0-54 /opt/cloudera/cem/efm
ln -s /opt/cloudera/cem/minifi-0.6.0.1.0.0.0-54 /opt/cloudera/cem/minifi
ln -s /opt/cloudera/cem/efm/bin/efm.sh /etc/init.d/efm
chown -R root:root /opt/cloudera/cem/efm-1.0.0.1.0.0.0-54
chown -R root:root /opt/cloudera/cem/minifi-0.6.0.1.0.0.0-54
chown -R root:root /opt/cloudera/cem/minifi-toolkit-0.6.0.1.0.0.0-54
rm -f /opt/cloudera/cem/efm/conf/efm.properties
cp ~/OneNodeCDHCluster/efm.properties /opt/cloudera/cem/efm/conf
rm -f /opt/cloudera/cem/minifi/conf/bootstrap.conf
cp ~/OneNodeCDHCluster/bootstrap.conf /opt/cloudera/cem/minifi/conf
sed -i "s/YourHostname/`hostname -f`/g" /opt/cloudera/cem/efm/conf/efm.properties
sed -i "s/YourHostname/`hostname -f`/g" /opt/cloudera/cem/minifi/conf/bootstrap.conf
/opt/cloudera/cem/minifi/bin/minifi.sh install


echo "-- Enable passwordless root login via rsa key"
ssh-keygen -f ~/myRSAkey -t rsa -N ""
mkdir ~/.ssh
cat ~/myRSAkey.pub >> ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys
ssh-keyscan -H `hostname` >> ~/.ssh/known_hosts
sed -i 's/.*PermitRootLogin.*/PermitRootLogin without-password/' /etc/ssh/sshd_config
systemctl restart sshd

echo "-- Start CM, it takes about 2 minutes to be ready"
systemctl start cloudera-scm-server

while [ `curl -s -X GET -u "admin:admin"  http://localhost:7180/api/version` -z ] ;
    do
    echo "waiting 10s for CM to come up..";
    sleep 10;
done

echo "-- Now CM is started and the next step is to automate using the CM API"

yum install -y epel-release
yum install -y python-pip
pip install --upgrade pip
pip install cm_client

sed -i "s/YourHostname/`hostname`/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s/YourCDSWDomain/cdsw.$PUBLIC_IP.nip.io/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s/YourPrivateIP/$PRIVATE_IP/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s#YourDockerDevice#$DOCKERDEVICE#g" ~/OneNodeCDHCluster/$TEMPLATE

sed -i "s/YourHostname/`hostname`/g" ~/OneNodeCDHCluster/create_cluster.py

python ~/OneNodeCDHCluster/create_cluster.py $TEMPLATE

# configure and start EFM and Minifi
service efm start
#service minifi start

# create copies of the config folders for spark and hdfs to work from CDSW.
# the trick is to replace the hostname with the private IP so that the host can be found.
# IBM cloud currently doesn't resolve internal hostnames.
mkdir /etc/spark/conf2
cp -R /etc/spark/conf/* /etc/spark/conf2
sed -i "s/`hostname`/$PRIVATE_IP/g" /etc/spark/conf/*
sed -i "s/`hostname`/$PRIVATE_IP/g" /etc/spark/conf/yarn-conf/*

mkdir /etc/hadoop/conf2
cp -R /etc/hadoop/conf/* /etc/hadoop/conf2
sed -i "s/`hostname`/$PRIVATE_IP/g" /etc/hadoop/conf/*

export HADOOP_CONF_DIR=/etc/hadoop/conf2
export SPARK_CONF_DIR=/etc/spark/conf2

