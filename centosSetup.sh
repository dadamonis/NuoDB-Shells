#! /bin/bash

echo "--> Updating RH/CentOS System...please wait this may take 10 or more minutes..."

echo "--> Updating yum..." &>> setup.debug
yum -y update &>> setup.debug
yum -y install wget &>> setup.debug

echo "--> Installing java-1.7.0-openjdk..." &>> setup.debug
yum -y install java-1.7.0-openjdk &>> setup.debug


echo "--> Disabling THP..." &>> setup.debug
#echo never > /sys/kernel/mm/transparent_hugepage/enabled &>> setup.debug
#echo never > /sys/kernel/mm/transparent_hugepage/defrag &>> setup.debug
cat /sys/kernel/mm/transparent_hugepage/enabled &>> setup.debug

echo "--> Disabling Firewall/iptables..." &>> setup.debug
/etc/init.d/iptables save &>> setup.debug
/etc/init.d/iptables stop &>> setup.debug

echo "--> Downloading and Installing NuoDB..."
echo "" &>> setup.debug

echo "--> WGET NuoDB Install Binary" &>> setup.debug
wget https://www.dropbox.com/s/1cr967hvb4nsl3r/nuodb-2.1.1-1.x86_64.rpm &>> setup.debug
echo "" &>> setup.debug

echo "--> Installing and configuring NuoDB..." &>> setup.debug
rpm --install nuodb-2.1.1-1.x86_64.rpm &>> setup.debug
echo "--> Set domain password..." &>> setup.debug
sed -i 's/#domainPassword =/domainPassword = bird/' /opt/nuodb/etc/default.properties 
echo "Set Peer..." &>> setup.debug
sed -i 's/#peer =/peer = 10.187.51.130/' /opt/nuodb/etc/default.properties
echo "Set broker = false" &>> setup.debug
sed -i 's/broker = true/broker = false/' /opt/nuodb/etc/default.properties
echo "Set --mem..." &>> setup.debug
echo "mem 8g" >> /opt/nuodb/etc/nuodb.config
