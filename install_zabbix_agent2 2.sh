#!/bin/bash
# Zabbix Agent2 Installer (Custom RHEL Script)
# Zabbix version: 7.0
# Author: Saurabh
 
ZBX_SERVER="3.6.114.164"
PSK_KEY="42e6288b4fe0ada2ca37c7025090458eb5a721d0915b61ae031ef56165acf90b"
PSK_FILE="/etc/zabbix/zabbix_agentd.psk"
CONF_FILE="/etc/zabbix/zabbix_agent2.conf"
LOGFILE="/var/log/zabbix_agent2_install.log"
 
echo "[$(date)] Starting Zabbix Agent2 installation..." | tee -a $LOGFILE
 
# Install curl if missing
if ! command -v curl &>/dev/null; then
    echo "[INFO] Installing curl..." | tee -a $LOGFILE
    yum install -y curl || dnf install -y curl
fi
 
# Install Zabbix repo for RHEL 7 (7.0 version)
echo "[INFO] Adding Zabbix repo..." | tee -a $LOGFILE
sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-7.0-1.el7.noarch.rpm
yum clean all
yum install -y zabbix-agent2 || dnf install -y zabbix-agent2
 
# Fetch Instance ID
INSTANCE_ID=$(TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
 
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/instance-id)
 
if [ -z "$INSTANCE_ID" ]; then
    echo "[WARN] Could not fetch instance ID. Using hostname instead." | tee -a $LOGFILE
    INSTANCE_ID=$(hostname)
fi
echo "[INFO] Using Hostname: $INSTANCE_ID" | tee -a $LOGFILE
 
# Configure zabbix_agent2.conf
sed -i 's/^Server=.*/#Server=/' $CONF_FILE
sed -i 's/^ServerActive=127.0.0.1/#ServerActive=127.0.0.1/' $CONF_FILE
sed -i "s|^# ServerActive=.*|ServerActive=$ZBX_SERVER|" $CONF_FILE
sed -i "s|^Hostname=.*|Hostname=$INSTANCE_ID|" $CONF_FILE
grep -q "^TLSConnect=" $CONF_FILE || echo "TLSConnect=psk" >> $CONF_FILE
grep -q "^TLSPSKIdentity=" $CONF_FILE || echo "TLSPSKIdentity=MyZabbixPSK" >> $CONF_FILE
grep -q "^TLSPSKFile=" $CONF_FILE || echo "TLSPSKFile=$PSK_FILE" >> $CONF_FILE
 
# Create PSK file
echo "$PSK_KEY" > $PSK_FILE
chmod 600 $PSK_FILE
chown zabbix:zabbix $PSK_FILE
 
# Restart service
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2
 
if systemctl is-active --quiet zabbix-agent2; then
    echo "[SUCCESS] Zabbix Agent2 installed and running!" | tee -a $LOGFILE
else
    echo "[ERROR] Zabbix Agent2 failed to start. Check logs." | tee -a $LOGFILE
    exit 1
fi
 
# Display Hostname from config
cat /etc/zabbix/zabbix_agent2.conf | grep ^Hostname