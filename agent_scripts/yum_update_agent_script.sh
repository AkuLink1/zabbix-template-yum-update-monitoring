#!/bin/sh
# Author:       Moluss
# Website       https://github.com/Moluss
# Description:  Yum updates Monitor using Zabbix via command `yum check-update`
#

# Route for tmp file to store yum output
TEMP_ZBX_FILE=/tmp/zabbix_yum_check_output.tmp
echo -n "" > $TEMP_ZBX_FILE

ZBX_HOSTNAMEITEM_PRESENT=$(egrep ^HostnameItem /etc/zabbix_agentd.conf -c)
ZBX_SERVERACTIVEITEM=$(egrep ^ServerActive /etc/zabbix_agentd.conf | cut -d = -f 2)

# Check if ServerActive is available
if [ -z "$ZBX_SERVERACTIVEITEM" ]; then
   echo "Agent is not running on active mode"
   exit -1
fi

# Get hostname
if [ "$ZBX_HOSTNAMEITEM_PRESENT" -ge "1" ]; then
        ZBX_HOSTNAME=$(hostname)
else
        ZBX_HOSTNAME=$(egrep ^Hostname /etc/zabbix_agentd.conf | cut -d = -f 2)
fi

CHECK_UPDATES=$(yum check-update)
# Check if updates are available TODO: If No packages marked for update matches or if an empty line is not found
if [ $(echo "$CHECK_UPDATES" | grep -c "No packages marked for update") -ge "1" ] || [ $(echo "$CHECK_UPDATES" | grep -c '^$') -eq "0" ]; then
  TOTAL_PACKAGES_COUNT=0
  APT_UPDATES_SUMMARY=0
else
  APT_UPDATES_SUMMARY=$(yum check-update | awk -vRS= 'END{print}')
  TOTAL_PACKAGES_COUNT=$(echo "$APT_UPDATES_SUMMARY" | wc -l)
fi

for (( i=1; i <= $TOTAL_PACKAGES_COUNT; i++ ))
do
  array[$i]=$(echo "$APT_UPDATES_SUMMARY" | awk "NR == $i" )
done

########
# Add to file and send to Zabbix Server
########
for i in "${array[@]}"
do
  echo "\"$ZBX_HOSTNAME\" yum.individualpackagetoupdate $i" >> $TEMP_ZBX_FILE
done

# Yum Update Full Summary
echo "\"$ZBX_HOSTNAME\" yum.packagestoupdate.count $TOTAL_PACKAGES_COUNT" >> $TEMP_ZBX_FILE
echo "\"$ZBX_HOSTNAME\" yum.packagestoupdate.description" $APT_UPDATES_SUMMARY >> $TEMP_ZBX_FILE

zabbix_sender -z $ZBX_SERVERACTIVEITEM -i $TEMP_ZBX_FILE