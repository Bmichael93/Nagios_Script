#!/bin/bash
# Created by: Benjamin Michael
# Date: August 2014
user="$USER"
echo "Using sudo powers -- Activate!"

function install_nagios() {
	cd /etc/
	sudo sed -i '1i192.168.1.3	raspberrypi.net	raspberrypi' hosts
	cd ~
	echo "Updating repository list..."
	sudo apt-get update -y
	sudo apt-get install build-essential apache2 apache2-utils php5-gd wget libgd2-xpm-dev libapache2-mod-php5 sendmail daemon -y
	sudo useradd nagios
	sudo groupadd nagcmd
	sudo usermod -a -G nagcmd nagios
	echo "Grabing Nagios Core from the internet..."
	sudo wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.0.8.tar.gz
	sudo tar -xvzf nagios-4.0.8.tar.gz
	cd nagios-4.0.8/
	echo "Configuring Nagios Core..."
	sudo ./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/bin/sendmail
	sudo make all
	sudo make install
	sudo make install-init
	sudo make install-config
	sudo make install-commandmode
	sudo make install-webconf
	cd ..
	sudo cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
	sudo chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers
	cd ~
	echo "Grabing Nagios Plugins from the internet..."
	sudo wget http://nagios-plugins.org/download/nagios-plugins-2.0.3.tar.gz
	sudo tar -xvzf nagios-plugins-2.0.3.tar.gz
	cd nagios-plugins-2.0.3/
	sudo ./configure --with-nagios-user=nagios --with-nagios-group=nagios
	sudo make
	sudo make install
	sudo cp /etc/apache2/conf.d/nagios.conf /etc/apache2/sites-available/nagios
	sudo ln -s /etc/apache2/sites-available/nagios /etc/apache2/sites-enabled/nagios
	echo "Checking for Nagios configuration errors!"
	sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
	echo "Adding Nagios and Apache to start on boot..."
	sudo ln -s /etc/init.d/nagios /etc/rcS.d/S98nagios
	sudo ln -s /etc/init.d/apache2 /etc/rcS.d/S99apache2
	echo "Restarting Nagios and Apache2 services..."
	sudo service nagios start
	sudo service apache2 start
	echo ""
	sudo usermod -a -G nagios $user 
	sudo service nagios restart
	sudo service apache2 restart
	echo "Open http://IPADDRESS/nagios or http://FQDN/nagios in your browser and enter username and password created"
	echo "Type in Nagios Web Login Password"
	echo "To change your web admin password from default, run this: sudo htpasswd -cm /usr/local/nagios/etc/htpasswd.users nagiosadmin"
	echo "To fix manual admin emails, add www-data to nagios and nagcmd groups in /etc/groups"    
	  
}

function configure_nagios() {
	cd ~
	#sudo apt-get update -y
	sudo apt-get install ssmtp -y
	sudo apt-get install mailutils -y
	sudo chown ben /etc/ssmtp/ssmtp.conf /etc/ssmtp/revaliases
	cd /usr/local/nagios/etc/objects/
	echo "Enter Nagios Admin Email Account: "
	read ADMINEMAIL
	sudo sed -i "s/nagios@localhost/$ADMINEMAIL/g" contacts.cfg
	cd /etc/
	echo "Enter your Gmail Username: "
	read GMAILUSERNAME
	echo "Enter your Gmail Password: "
	read -s GMAILPASS 
	sudo sed -i '1i192.168.1.3	raspberrypi.net	raspberrypi' hosts
	sudo sed -i '/mailhub=mail/d' /etc/ssmtp/ssmtp.conf
	sudo sed -i '9s/.*/mailhub=smtp.gmail.com:587/' /etc/ssmtp/ssmtp.conf
	sudo echo "AuthUser=$GMAILUSERNAME" >> /etc/ssmtp/ssmtp.conf
	sudo echo "AuthPass=$GMAILPASS" >> /etc/ssmtp/ssmtp.conf
	sudo echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf
	cd /etc/ssmtp/
	echo "root:root@$HOSTNAME:smtp.gmail.com:587" >> /etc/ssmtp/revaliases
	sudo chmod 774 /etc/ssmtp/ssmtp.conf
	sudo chown -R nagios:www-data /usr/local/nagios/var/rw/
	sudo service nagios restart
	echo 'Test sending an email by using command: echo "Test text" | mail -s "Test Mail" targetperson@example.com'
	echo "Check if your sendmail is under bin or sbin. Change /usr/local/nagios/etc/objects/commands for notify-by-email."
}
if [ $# -eq 0 ]
then
	OPT_ERROR=1
fi

while getopts "ich" flag; do
	case $flag in
	\?) OPT_ERROR=1; break;;
	h) OPT_ERROR=1; break;;
	i) opt_install=true;;
	c) opt_configure=true;;
	esac
done

shift $(($OPTIND - 1 ))

if [ $OPT_ERROR ]
then 
	echo >&2 "USAGE ERROR: $0 [-ich]
	-i : install nagios
	-c : configure nagios with given options
	-h : show this help menu"
	exit 1
fi

if [ "$opt_install" = "true" ]
then
	install_nagios
fi
if [ "$opt_configure" = "true" ]
then
	configure_nagios
fi

