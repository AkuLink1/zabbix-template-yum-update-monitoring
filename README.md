# Zabbix Template to monitor available package updates from yum in hosts
Zabbix template that monitors a host for package upgrades available in RHEL / CentOS / yum package manager distros using `yum check-update command`

## Overview
Zabbix Server version: 6.0

Agent must be running active mode, ServerActive must have a value.

Sample output of `yum check-update` from which we extract the info for the template:

    ImageMagick6-libs.x86_64                                                            6.9.12.50-1.el7.remi                                                        remi-safe
	grub2.x86_64                                                                        1:2.02-0.87.el7.9                                                           updates
	gzip.x86_64                                                                         1.5-11.el7_9                                                                updates
	kernel.x86_64                                                                       3.10.0-1160.66.1.el7                                                        updates
	kernel-headers.x86_64                                                               3.10.0-1160.66.1.el7                                                        updates
	zlib.x86_64                                                                         1.2.7-20.el7_9                                                              updates

# Versions 
This template was tested on:

- Zabbix Server 6.0 (LTS)
- Zabbix Agent (daemon) 5.0.21
- CentOS 7

# Setup

## On Zabbix frontend server:
- Download and import one of these files (only difference between files is format):  `server_template_check_yum_updates_template.xml`, `server_template_check_yum_updates_template.json`, `server_template_check_yum_updates_template.yml` to Zabbix frontend.

- Assign the `Template Yum Check-Update Monitor` to the host(s) you want to monitor

## On all hosts you want to monitor:
- Install packages zabbix-agent and zabbix-sender (if not installed):

     `apt-get install zabbix-agent zabbix-sender`

- Copy or wget agent_scripts/apt_upgrade_agent_script.sh from this repo into host folder (example): /etc/zabbix/custom_scripts

- Grant exec permissions (`sudo chmod +x`)

- Add entry to crontab (`sudo crontab -e`) to execute the script periodically, check for possible upgrades and send to Zabbix Server. This cron will run every 12 hours:

     `0 */12 * * * sh /etc/zabbix/custom_scripts/yum_update_agent_script.sh`