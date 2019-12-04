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

sed -i "s/YourHostname/`hostname -f`/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s/YourCDSWDomain/cdsw.$PUBLIC_IP.nip.io/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s/YourPrivateIP/`hostname -I | tr -d '[:space:]'`/g" ~/OneNodeCDHCluster/$TEMPLATE
sed -i "s#YourDockerDevice#$DOCKERDEVICE#g" ~/OneNodeCDHCluster/$TEMPLATE

sed -i "s/YourHostname/`hostname -f`/g" ~/OneNodeCDHCluster/scripts/create_cluster.py

python ~/OneNodeCDHCluster/scripts/create_cluster.py $TEMPLATE

# configure and start EFM and Minifi
service efm start
#service minifi start

echo "-- At this point you can login into Cloudera Manager host on port 7180 and follow the deployment of the cluster"