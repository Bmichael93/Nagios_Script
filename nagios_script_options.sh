#!/bin/bash
# Created by: Benjamin Michael
# Date: August 2014
#######################################################
#Variables
user="$USER"
alertemail="alert@example.com"
securityIP="192.168.1.0/24"
#######################################################

echo "Using sudo powers -- Activate!"
sudo su
function install_nagios() {
	cd /etc/
	sudo sed -i '1i192.168.1.5	raspberrypi2.net	raspberrypi2' hosts
	cd ~
	echo "Updating repository list..."
	# Update OS
	sudo apt-get update -y
	sudo apt-get install build-essential apache2 apache2-utils php5-gd wget libgd2-xpm-dev libapache2-mod-php5 sendmail daemon -y
	
	# Add Nagios User
	echo "Add Nagios user..."
	if [ $(id -u) -eq 0 ]; then
	read -p "Enter username: " username
	read -s -p "Enter password : " password
	egrep "^$username" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
	  echo "$username exists!"
	  exit 1
	else
	  pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
	  useradd -m -p $pass $username
	  
	  # Adding nagios nagcmd group
	  echo "Adding nagios nagcmd group..."
	  sudo groupadd nagcmd
	  sudo usermod -a -G nagcmd $username
	  sudo usermod -a -G nagcmd www-data
	  [ $? -eq 0] && echo "User has been added to system!" || echo "Failed to add user!"
	fi else
	echo "Only root may add a user to the system"
	exit 2
	fi
	
	echo "Grabing Nagios Core from the internet..."
	# Grab the software 
	cd /tmp
	sudo wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.1.1.tar.gz
	sudo tar -xvzf nagios-4.1.1.tar.gz
	cd nagios-4.1.1/
	
	echo "Configuring Nagios Core..."
	# Configure and install nagios core
	sudo ./configure --with-command-group=nagcmd --with-mail=/usr/bin/sendmail
	sudo make all
	sudo make install
	sudo make install-init
	sudo make install-config
	sudo make install-commandmode
	sudo make install-webconf
    
	# sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-enabled/nagios.conf
	
	cd /tmp
	
	echo "Grabing Nagios Plugins from the internet..."
	# Configure and install nagios plugins
	sudo wget http://nagios-plugins.org/download/nagios-plugins-2.1.1.tar.gz
	sudo tar -xvzf nagios-plugins-2.1.1.tar.gz
	cd nagios-plugins-2.1.1/
	sudo ./configure --with-nagios-group=nagcmd
	sudo make
	sudo make install
	sudo cp /etc/apache2/conf.d/nagios.conf /etc/apache2/sites-available/nagios
	sudo ln -s /etc/apache2/sites-available/nagios /etc/apache2/sites-enabled/nagios
	
	# Error Check!
	echo "Checking for Nagios configuration errors!"
	sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
	
	# Finalizing Install
	echo "Adding Nagios and Apache to start on boot..."
	sudo ln -s /etc/init.d/nagios /etc/rcS.d/S98nagios
	sudo ln -s /etc/init.d/apache2 /etc/rcS.d/S99apache2
	
	echo "Restarting Nagios and Apache2 services..."
	sudo service nagios restart
	sudo service apache2 restart
	echo ""
	
	# Web GUI Stuff
	echo "Open http://IPADDRESS/nagios or http://FQDN/nagios in your browser and enter username and password created"
	echo "Type in Nagios Web Login Password"
	sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
	echo ""
	echo "To change your web admin password from default, run this: sudo htpasswd -cm /usr/local/nagios/etc/htpasswd.users nagiosadmin"
}

function configure_nagios() {
	cd ~
	echo "Adding email to alerts..."
	sed -i 's/nagios@localhost/$alertemail/g' /usr/local/nagios/etc/objects/contacts.cfg
	
	echo "Changing security IP allow clause to LAN network..."
	sed -i 's\# Allow from 127.0.0.1\ Allow from $securityIP\g' /etc/apache2/conf.d/nagios.conf
	
	
	#sudo apt-get update -y
	sudo apt-get install sendemail -y
	
	echo "Use as follows:"
	echo "sendEmail -f from@domain.tld -t to@domain.tld -s smtp.domain.tld -u "Subject" -m "Message" -xu username -xp password"
	
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
	c) opt_sendemail=true;;
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
if [ "$opt_sendemail" = "true" ]
then
	configure_nagios
fi

