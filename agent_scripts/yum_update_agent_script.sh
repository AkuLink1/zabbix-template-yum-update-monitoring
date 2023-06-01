#!/bin/sh
# Author:       Moluss
# Website       https://github.com/Moluss
# Description:  Yum updates Monitor using Zabbix via command `yum check-update`
# 2023-05-31 updated to support Zabbix server ports

# Server configuration file route
AGENTD_CONF_FILE=/etc/zabbix_agentd.conf
USE_ENCRYPTION=0

# Route for tmp file to store yum output
TEMP_ZBX_FILE=/tmp/zabbix_yum_check_output.tmp
echo -n "" > $TEMP_ZBX_FILE

if [ ! -f "$AGENTD_CONF_FILE" ]; then
  echo "Error: File '$AGENTD_CONF_FILE' does not exist."
  exit 1
fi


# Check if Server IP/name is set in configuration file
ZBX_SERVERACTIVEITEM=$(egrep ^ServerActive $AGENTD_CONF_FILE | cut -d = -f 2)

# Check if ServerActive is available
if [ -z "$ZBX_SERVERACTIVEITEM" ]; then
   echo "Agent is not running on active mode"
   exit 1
fi

# Extract the hostname and port using pattern matching
line=$(grep "^ServerActive=" $AGENTD_CONF_FILE)
if echo "$line" | grep -Eq "ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?$"; then

  # Store the hostname
  ZBX_SERVERACTIVEITEM=$(echo "$line" | sed -E 's/ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?/\1/')

  # Store the port
  ZBX_SERVERACTIVEITEM_PORT=$(echo "$line" | sed -E 's/ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?/\3/')
  if [ -z "$ZBX_SERVERACTIVEITEM_PORT" ]; then
    ZBX_SERVERACTIVEITEM_PORT="10051"
  fi

else
  echo "Error: Unable to find the ServerActive line"
  exit 1
fi

# Get hostname
ZBX_HOSTNAMEITEM_PRESENT=$(egrep ^HostnameItem $AGENTD_CONF_FILE -c)
if [ "$ZBX_HOSTNAMEITEM_PRESENT" -ge "1" ]; then
        ZBX_HOSTNAME=$(hostname)
else
        ZBX_HOSTNAME=$(egrep ^Hostname $AGENTD_CONF_FILE | cut -d = -f 2)
fi


# Read the PSK identity and file from zabbix_agentd.conf
if [ "$USE_ENCRYPTION" -ge "1" ]; then
	psk_identity=$(sed -n 's/^TLSPSKIdentity[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	psk_file=$(sed -n 's/^TLSPSKFile[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	tls_connect=$(sed -n 's/^TLSConnect[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	
	if [[ -n $psk_identity ]]; then
	        psk_identity="--tls-psk-identity $psk_identity"
	fi
	
	if [[ -n $psk_file ]]; then
	        psk_file="--tls-psk-file $psk_file"
	fi
	
	if [[ -n $tls_connect ]]; then
	        tls_connect="--tls-connect $tls_connect"
	fi
fi

#######
# YUM Update
#######

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
  i=$(echo "$i" | tr -s ' ')
  echo "\"$ZBX_HOSTNAME\" yum.individualpackagetoupdate \"$i\"" >> $TEMP_ZBX_FILE
done

# Remove line breaks using 'tr' command
APT_UPDATES_SUMMARY=$(echo "$APT_UPDATES_SUMMARY" | tr -d '\n')
# Replace multiple spaces with a single space
APT_UPDATES_SUMMARY=$(echo "$APT_UPDATES_SUMMARY" | tr -s ' ')

# Yum Update Full Summary
echo "\"$ZBX_HOSTNAME\" yum.packagestoupdate.count $TOTAL_PACKAGES_COUNT" >> $TEMP_ZBX_FILE
echo "\"$ZBX_HOSTNAME\" yum.packagestoupdate.description \"$APT_UPDATES_SUMMARY\"" >> $TEMP_ZBX_FILE
zabbix_sender -z $ZBX_SERVERACTIVEITEM -p $ZBX_SERVERACTIVEITEM_PORT $psk_identity $psk_file $tls_connect -i $TEMP_ZBX_FILE

