#!/bin/bash
	# bron: https://www.howtoforge.com/tutorial/ubuntu-nagios/
	# bron: https://github.com/dyson/nagios-ubuntu-install-script
	# bron: https://serverfault.com/questions/774498/failed-to-start-nagios-service-unit-nagios-service-failed-to-load-no-such-file
	# bron: https://lintut.com/adding-clients-to-nagios-server/

# variablen
NAGIOS_VERSION="4.3.2"
NAGIOS_PLUGIN="2.2.2"
NAGIOS_USERNAME="nagiosadmin"
NAGIOS_PASSWORD="admin"

TEMP="/tmp/download"


# Prerequisites
sudo apt-get update
sudo apt-get --yes install wget build-essential apache2 php apache2-mod-php7.0 php-gd libgd-dev sendmail unzip


# User and group configuration
sudo useradd nagios
sudo groupadd nagcmd
sudo usermod -a -G nagcmd nagios
sudo usermod -a -G nagios,nagcmd www-data

# Download Nagios
mkdir -p $TEMP
cd $TEMP
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-$NAGIOS_VERSION.tar.gz
tar -xzf nagios-$NAGIOS_VERSION.tar.gz
cd nagios-$NAGIOS_VERSION


# Compile & install nagios
./configure --with-nagios-group=nagios --with-command-group=nagcmd

make all
sudo make install
sudo make install-commandmode
sudo make install-init
sudo make install-config
sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf

sudo cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
sudo chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers


# download Plugins
cd $TEMP
wget https://nagios-plugins.org/download/nagios-plugins-$NAGIOS_PLUGIN.tar.gz
tar -xzf nagios-plugins-$NAGIOS_PLUGIN.tar.gz
cd nagios-plugins-$NAGIOS_PLUGIN/


# Install Plugins
sudo ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
sudo make install

sudo apt-get --yes install nagios-plugins
sudo cp /usr/lib/nagios/plugins/check_* /usr/local/nagios/libexec
sudo apt-get --yes install nagios-nrpe-server nagios-plugins


# Configure nagios
sudo sh -c 'echo 'cfg_dir=/usr/local/nagios/etc/servers' >> /usr/local/nagios/etc/nagios.cfg'
sudo mkdir -p /usr/local/nagios/etc/servers


# Service nagios aanmaken
sudo sh -c 'echo "[Unit]" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "Description=Nagios" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "BindTo=network.target" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo " " >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "[Install]" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "WantedBy=multi-user.target" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo " " >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "[Service]" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "User=nagios" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "Group=nagios" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "Type=simple" >> /etc/systemd/system/nagios.service'
sudo sh -c 'echo "ExecStart=/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg" >> /etc/systemd/system/nagios.service'
sudo systemctl enable /etc/systemd/system/nagios.service


# Gebruiker nagios aanmaken
sudo htpasswd -bc /usr/local/nagios/etc/htpasswd.users $NAGIOS_USERNAME $NAGIOS_PASSWORD

# Configuring Apache
sudo a2enmod rewrite
sudo a2enmod cgi
sudo ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/


# services starten
sudo service apache2 restart
sudo systemctl start nagios
sudo ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios


#Minion1 toevoegen
sudo sh -c 'echo "define host{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use linux-server" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name Minion1" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "alias client" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "address 192.168.2.144" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "contact_groups admins" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "max_check_attempts 5" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_period 24x7" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "notification_interval 30" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "notification_period 24x7" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'


# check disk
sudo sh -c 'echo "define service{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use                             generic-service" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name                       Minion1" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "service_description             Root Partition" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "contact_groups                  admins" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_command                   check_nrpe!check_disk" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'

#check processes
sudo sh -c 'echo "define service{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use                             generic-service" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name                       Minion1" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "service_description     		  Total Processes" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_command          		  check_nrpe!check_total_procs" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'


#Minion2 toevoegen
sudo sh -c 'echo "define host{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use linux-server" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name Minion2" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "alias client" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "address 192.168.2.145" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "contact_groups admins" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "max_check_attempts 5" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_period 24x7" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "notification_interval 30" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "notification_period 24x7" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'

# check disk
sudo sh -c 'echo "define service{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use                             generic-service" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name                       Minion2" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "service_description             Root Partition" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "contact_groups                  admins" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_command                   check_nrpe!check_disk" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'

#check processes
sudo sh -c 'echo "define service{" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "use                             generic-service" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "host_name                       Minion2" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "service_description     		  Total Processes" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "check_command          		  check_nrpe!check_total_procs" >> /usr/local/nagios/etc/servers/clients.cfg'
sudo sh -c 'echo "}" >> /usr/local/nagios/etc/servers/clients.cfg'

sudo systemctl restart nagios




















