#!/bin/env bash
#####    NOTES             ###################################
# Project Page: https://github.com/Zer0CoolX/guacamole-install-rhel
# Licence (GPL-3.0): https://github.com/Zer0CoolX/guacamole-install-rhel/blob/master/LICENSE
# Report Issues: https://github.com/Zer0CoolX/guacamole-install-rhel/issues
# Wiki: https://github.com/Zer0CoolX/guacamole-install-rhel/wiki
#
# WARNING: For use on RHEL/CentOS 7.x and up only.
#	-Use at your own risk!  
#	-Use only for new installations of Guacamole!
# 	-Read all documentation prior to using this script!
#	-Test prior to deploying on a production system!
#
#####    UNIVERSAL VARS    ###################################
# USER CONFIGURABLE        #
# Generic
SCRIPT_BUILD="2018_11_29" # Scripts Date for last modified as "yyyy_mm_dd"
ADM_POC="Local Admin, admin@admin.com"  # Point of contact for the Guac server admin

# Versions
GUAC_STBL_VER="0.9.14"
MYSQL_CON_VER="8.0.13"
LIBJPEG_VER="2.0.1"
MAVEN_VER="3.6.0"

# Ports
GUAC_PORT="4822"
MYSQL_PORT="3306"

# Key Sizes
JKSTORE_KEY_SIZE_DEF="4096" # Default Java Keystore key-size
LE_KEY_SIZE_DEF="4096" # Default Let's Encrypt key-size
SSL_KEY_SIZE_DEF="4096" # Default Self-signed SSL key-size
DHE_KEY_SIZE_DEF="2048" # Default DHE/Forward Secrecy key-size

# Default Credentials
MYSQL_PASSWD_DEF="guacamole" # Default MySQL/MariaDB root password
DB_NAME_DEF="guac_db" # Defualt database name
DB_USER_DEF="guac_adm" # Defualt database user name
DB_PASSWD_DEF="guacamole" # Defualt database password
JKSTORE_PASSWD_DEF="guacamole" # Default Java Keystore password

# Misc
GUAC_URIPATH_DEF="/"
GUACSERVER_HOSTNAME_DEF="localhost"

# ONLY CAHNGE IF NOT WORKING #
# URLS
MYSQL_CON_URL="https://dev.mysql.com/get/Downloads/Connector-J/" #Direct URL for download
LIBJPEG_URL="https://sourceforge.net/projects/libjpeg-turbo/files/${LIBJPEG_VER}/" #libjpeg download path

# Dirs and File Names
LIB_DIR="/var/lib/guacamole/"
GUAC_CONF="guacamole.properties"
MYSQL_CON="mysql-connector-java-${MYSQL_CON_VER}"
LIBJPEG_TURBO="libjpeg-turbo-official-${LIBJPEG_VER}"

# Formats
Black=`tput setaf 0`   #${Black}
Red=`tput setaf 1`     #${Red}
Green=`tput setaf 2`   #${Green}
Yellow=`tput setaf 3`  #${Yellow}
Blue=`tput setaf 4`    #${Blue}
Magenta=`tput setaf 5` #${Magenta}
Cyan=`tput setaf 6`    #${Cyan}
White=`tput setaf 7`   #${White}
Bold=`tput bold`       #${Bold}
Rev=`tput smso`        #${Rev}
Reset=`tput sgr0`      #${Reset}

# Install Mode
INSTALL_MODE="interactive"
##### END UNIVERSAL VARS   ###################################

##### CHECK FOR SUDO or ROOT ################################## 
if ! [ $(id -u) = 0 ]; then echo "This script must be run as sudo or root, try again..."; exit 1 ; fi

#####    INITIALIZE COMMON VARS    ###################################
# ONLY CAHNGE IF NOT WORKING #
init_vars () {
GUAC_GIT_VER=`curl -s https://raw.githubusercontent.com/apache/guacamole-server/master/configure.ac | grep 'AC_INIT([guacamole-server]*' | awk -F'[][]' -v n=2 '{ print $(2*n) }'`
PWD=`pwd`
REGEX_MAIL="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
REGEX_IDN="(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)"

# Determine if OS is RHEL or not (otherwise assume CentOS)
if rpm -q subscription-manager 2>&1 > /dev/null; then IS_RHEL=true; else IS_RHEL=false; fi

MAJOR_VER=`cat /etc/redhat-release | grep -oP "[0-9]+" | head -1` # Return 5, 6 or 7 when OS is 5.x, 6.x or 7.x

if [ $IS_RHEL = true ]; then OS_NAME="RHEL"; else OS_NAME="CentOS"; fi

OS_NAME_L="$(echo $OS_NAME | tr '[:upper:]' '[:lower:]')" # Set lower case rhel or centos for use in some URLs

#Set arch used in some paths
MACHINE_ARCH=`uname -m`
if [ $MACHINE_ARCH="x86_64" ]; then ARCH="64"; elif [ $MACHINE_ARCH="i686" ]; then MACHINE_ARCH="i386"; else ARCH=""; fi

NGINX_URL=https://nginx.org/packages/$OS_NAME_L/$MAJOR_VER/$MACHINE_ARCH/ # Set nginx url for RHEL or CentOS
}

#####      SOURCE MENU       ###################################
src_menu () {
clear

echo -e "   ----====Installation Menu====----\n   ${Bold}Guacamole Remote Desktop Gateway" && tput sgr0
echo -e "   ${Bold}OS: ${Yellow}${OS_NAME} ${MAJOR_VER} ${MACHINE_ARCH}\n" && tput sgr0
echo -e "   ${Bold}Stable Version: ${Yellow}${GUAC_STBL_VER}${Reset} || ${Bold}Git Version: ${Yellow}${GUAC_GIT_VER}\n" && tput sgr0

while true; do
	read -p "${Green} Pick the desired source to install from (enter 'stable' or 'git', default is 'stable'): ${Yellow}" GUAC_SOURCE
	case $GUAC_SOURCE in
    	[Ss]table|"" ) GUAC_SOURCE="Stable"; break;;
		[Gg][Ii][Tt] ) GUAC_SOURCE="Git"; break;;
		* ) echo "${Green} Please enter 'stable' or 'git' to select source/version (without quotes)";;
  	esac
done
echo -e "Source (src_menu): ${GUAC_SOURCE}" >> /home/srlab/mylog.txt  2>&1
tput sgr0
}

#####      SOURCE VARIABLES       ###################################
src_vars () {
echo -e "Source (src_vars): ${GUAC_SOURCE}" >> /home/srlab/mylog.txt  2>&1
if [ $GUAC_SOURCE == "Git" ]; then
	GUAC_VER=${GUAC_GIT_VER}
	GUAC_URL="git://github.com/apache/"
	GUAC_SERVER="guacamole-server.git"
	GUAC_CLIENT="guacamole-client.git"
	MAVEN_MAJOR_VER=${MAVEN_VER:0:1}
	MAVEN_URL="https://www-us.apache.org/dist/maven/maven-${MAVEN_MAJOR_VER}/${MAVEN_VER}/binaries/"
	MAVEN_FN="apache-maven-${MAVEN_VER}"
	MAVEN_BIN="${MAVEN_FN}-bin.tar.gz"
else
	GUAC_VER=${GUAC_STBL_VER}
	GUAC_URL="https://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/"
	GUAC_SERVER="guacamole-server-${GUAC_VER}"
	GUAC_CLIENT="guacamole-${GUAC_VER}"
fi

GUAC_JDBC="guacamole-auth-jdbc-${GUAC_VER}"
GUAC_LDAP="guacamole-auth-ldap-${GUAC_VER}"

INSTALL_DIR="/usr/local/src/guacamole/${GUAC_VER}/"
FILENAME="${PWD}/guacamole-${GUAC_VER}_"$(date +"%d-%y-%b")""
logfile="${FILENAME}.log"
fwbkpfile="${FILENAME}.firewall.bkp" # Firewall backup file name
}

#####      INSTALL MENU       ###################################
install_menu () {
clear

echo -e "   ----====Installation Menu====----\n   ${Bold}Guacamole Remote Desktop Gateway \n   Source/Version: ${Yellow}${GUAC_SOURCE} ${GUAC_VER}" && tput sgr0
echo -e "   ${Bold}OS: ${Yellow}${OS_NAME} ${MAJOR_VER} ${MACHINE_ARCH}\n" && tput sgr0

echo -n "${Green} Enter the root password for MariaDB: ${Yellow}"
  	read MYSQL_PASSWD
  	MYSQL_PASSWD=${MYSQL_PASSWD:-${MYSQL_PASSWD_DEF}}
echo -n "${Green} Enter the Guacamole DB name (default ${DB_NAME_DEF}): ${Yellow}"
  	read DB_NAME
 	 DB_NAME=${DB_NAME:-${DB_NAME_DEF}}
echo -n "${Green} Enter the Guacamole DB username (default ${DB_USER_DEF}): ${Yellow}"
  	read DB_USER
  	DB_USER=${DB_USER:-${DB_USER_DEF}}
echo -n "${Green} Enter the Guacamole DB password: ${Yellow}"
 	 read DB_PASSWD
 	 DB_PASSWD=${DB_PASSWD:-${DB_PASSWD_DEF}}
echo -n "${Green} Enter the Java KeyStore password (at least 6 characters): ${Yellow}"
 	 read JKSTORE_PASSWD
 	 JKSTORE_PASSWD=${JKSTORE_PASSWD:-${JKSTORE_PASSWD_DEF}}
echo -n "${Green} Enter the Java KeyStore key-size to use (default ${JKSTORE_KEY_SIZE_DEF}): ${Yellow}"
 	 read JKSTORE_KEY_SIZE
 	 JKSTORE_KEY_SIZE=${JKSTORE_KEY_SIZE:-${JKSTORE_KEY_SIZE_DEF}}
nginxmenu
while true; do
    read -p "${Green} Do you use Let's Encrypt to create a Valid SSL Certificate? (default no): ${Yellow}" yn
    case $yn in
        [Yy]* ) LETSENCRYPT_CERT="yes"; letsencrypt; break;;
        [Nn]*|"" ) LETSENCRYPT_CERT="no"; selfsignmenu; break;;
        * ) echo "${Green} Please enter yes or no. ${Yellow}";;
    esac
done
while true; do
    read -p "${Green} Do you wish to install Guacamole's LDAP Extension? (default no): ${Yellow}" yn
    case $yn in
        [Yy]* ) INSTALL_LDAP="yes"; ldapmenu; break;;
        [Nn]*|"" ) INSTALL_LDAP="no"; break;;
        * ) echo "${Green} Please enter yes or no. ${Yellow}";;
    esac
done
while true; do
    read -p "${Green} Do you wish to install a custom Guacamole extension from a local file? (default no): ${Yellow}" yn
    case $yn in
        [Yy]* ) INSTALL_CUST="yes"; custmenu; break;;
        [Nn]*|"" ) INSTALL_CUST="no"; break;;
        * ) echo "${Green} Please enter yes or no. ${Yellow}";;
    esac
done
tput sgr0
}

#####    LETSENCRYPT MENU     ###################################
letsencrypt () {
CERTYPE="Let's Encrypt"
while true; do
  	echo -n "${Green} Enter a valid e-mail for let's encrypt certificate: ${Yellow}"
    	read EMAIL_NAME
  	if [[ $EMAIL_NAME =~ $REGEX_MAIL ]] ; then
    	break
  	else
    	echo "${Green} Please enter a correct e-mail address. ${Yellow}"
 	fi
done
while true; do
  	echo -n "${Green} Enter a valid domain for let's encrypt certificate (ex. gucamole.company.com): ${Yellow}"
    	read DOMAIN_NAME
  	if echo $DOMAIN_NAME | grep -P $REGEX_IDN > /dev/null; then
    	echo "${Green}   Remember that Let's Encrypt only support DNS-based validation."
    	break
  	else
    	echo "${Green} Please enter a correct domain name. ${Yellow}"
	fi
done
echo -n "${Green} Enter the Let's Encrypt key-size to use (default ${LE_KEY_SIZE_DEF}): ${Yellow}"
  	read LE_KEY_SIZE
  	LE_KEY_SIZE=${LE_KEY_SIZE:-${LE_KEY_SIZE_DEF}}
}

#####    NGINX MENU    ########################################
nginxmenu () {
CERTYPE="Self-Signed"

echo -n "${Green} Enter the Guacamole Server IP address or hostname (default ${GUACSERVER_HOSTNAME_DEF}): ${Yellow}"
  	read GUACSERVER_HOSTNAME
  	GUACSERVER_HOSTNAME=${GUACSERVER_HOSTNAME:-${GUACSERVER_HOSTNAME_DEF}}
echo -n "${Green} Enter the URI path, starting with / for example /guacamole (default ${GUAC_URIPATH_DEF}): ${Yellow}"
  	read GUAC_URIPATH
  	GUAC_URIPATH=${GUAC_URIPATH:-${GUAC_URIPATH_DEF}}
while true; do
    read -p "${Green} Use a more secure Nginx SSL configuration? (default no): ${Yellow}" yn
    case $yn in
        [Yy]* ) NGINX_HARDEN="yes"; nginxhardenmenu; break;;
        [Nn]*|"" ) NGINX_HARDEN="no"; break;;
        * ) echo "${Green} Please enter yes or no. ${Yellow}";;
    esac
done
}

#####    NGINX HARDEN MENU    ########################################
nginxhardenmenu () {
while true; do
    read -p "${Green} Use Forward Secrecy & DHE? ${Red}**This may take a long time!** (default no): ${Yellow}" yn
    case $yn in
        [Yy]* ) DHE_USE="yes"; dhemenu; break;;
        [Nn]*|"" ) DHE_USE="no"; break;;
        * ) echo "${Green} Please enter yes or no. ${Yellow}";;
    esac
done
}

#####    SELF SIGN MENU    ########################################
selfsignmenu () {
echo -n "${Green} Enter the Self-Signed SSL key-size to use (default ${SSL_KEY_SIZE_DEF}): ${Yellow}"
  	read SSL_KEY_SIZE
  	SSL_KEY_SIZE=${SSL_KEY_SIZE:-${SSL_KEY_SIZE_DEF}}
}

#####    DHE MENU    ########################################
dhemenu () {
echo -n "${Green} Enter the DHE key-size to use. ${Red}Higher key-size will take more time (default ${DHE_KEY_SIZE_DEF}): ${Yellow}"
  	read DHE_KEY_SIZE
  	DHE_KEY_SIZE=${DHE_KEY_SIZE:-${DHE_KEY_SIZE_DEF}}
}

#####    LDAP MENU    ########################################
ldapmenu () {
while true; do
	read -p "${Green} Use LDAPS instead of LDAP (Requires having the cert from the server copied locally, default: no): ${Yellow}" SECURE_LDAP
	case $SECURE_LDAP in
		[Yy]* ) SECURE_LDAP="yes"; break;;
		[Nn]*|"" ) SECURE_LDAP="no"; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
if [ $SECURE_LDAP == "yes" ]; then
	echo -n "${Green} Enter the LDAP Port (default 636): ${Yellow}"
  	read LDAP_PORT
  	LDAP_PORT=${LDAP_PORT:-636}

  	# LDAPS Certificate prompts
	LDAPS_CERT_FN="mycert.cer"
	LDAPS_CERT_FULL="xNULLx"

	while [ ! -f ${LDAPS_CERT_FULL} ]; do
		echo -n "${Green} Enter a valid filename of the .cer certificate file (Ex: mycert.cer): ${Yellow}"
			read LDAPS_CERT_FN
			LDAPS_CERT_FN=${LDAPS_CERT_FN:-${LDAPS_CERT_FN}}
		echo -n "${Green} Enter the full path of the dir containing the .cer certificate file (must end with / Ex: /home/me/): ${Yellow}"
			read LDAPS_CERT_DIR
			LDAPS_CERT_DIR=${LDAPS_CERT_DIR:-/home/}
			LDAPS_CERT_FULL=${LDAPS_CERT_DIR}${LDAPS_CERT_FN}
		if [ ! -f ${LDAPS_CERT_FULL} ]; then
			echo "${Red} The file/path: ${LDAPS_CERT_FULL} does not exist! Ensure the file is in the directory and try again..."
		fi
	done
	echo -n "${Green} Enter the cacerts keystore password (default changeit): ${Yellow}"
	read CA_PASSWD
	CA_PASSWD=${CA_PASSWD:-changeit}
else
	echo -n "${Green} Enter the LDAP Port (default 389): ${Yellow}"
  	read LDAP_PORT
  	LDAP_PORT=${LDAP_PORT:-389}
fi

echo -n "${Green} Enter the LDAP Server Hostname (use the FQDN, Ex: ldaphost.domain.com): ${Yellow}"
  	read LDAP_HOSTNAME
  	LDAP_HOSTNAME=${LDAP_HOSTNAME:-ldaphost.domain.com}
echo -n "${Green} Enter the LDAP User-Base-DN (Ex: dc=domain,dc=com): ${Yellow}"
  	read LDAP_BASE_DN
  	LDAP_BASE_DN=${LDAP_BASE_DN:-dc=domain,dc=com}
echo -n "${Green} Enter the LDAP Search-Bind-DN (Ex: cn=user,ou=Admins,dc=doamin,dc=com): ${Yellow}"
  	read LDAP_BIND_DN
  	LDAP_BIND_DN=${LDAP_BIND_DN:-cn=user,ou=Admins,dc=doamin,dc=com}
echo -n "${Green} Enter the LDAP Search-Bind-Password: ${Yellow}"
  	read LDAP_BIND_PW
  	LDAP_BIND_PW=${LDAP_BIND_PW:-password}
echo -n "${Green} Enter the LDAP Username-Attribute (default sAMAccountName): ${Yellow}"
  	read LDAP_UNAME_ATTR
  	LDAP_UNAME_ATTR=${LDAP_UNAME_ATTR:-sAMAccountName}
}

#####    CUSTOM EXTENSION MENU    ########################################
custmenu () {
# Set Defaults
CUST_FN="myextension.jar"
CUST_FULL="xNULLx"

while [ ! -f ${CUST_FULL} ]; do
	echo -n "${Green} Enter a valid filename of the .jar extension file (Ex: myextension.jar): ${Yellow}"
		read CUST_FN
		CUST_FN=${CUST_FN:-${CUST_FN}}
	echo -n "${Green} Enter the full path of the dir containing the .jar extension file (must end with / Ex: /home/me/): ${Yellow}"
		read CUST_DIR
		CUST_DIR=${CUST_DIR:-/home/}
		CUST_FULL=${CUST_DIR}${CUST_FN}
	if [ ! -f ${CUST_FULL} ]; then
		echo "${Red} The file/path: ${CUST_FULL} does not exist! Ensure the file is in the directory and try again..."
	fi
done
}

#####    SPINNER      ########################################
spinner () {
pid=$!

spin[0]="-"
spin[1]="\\"
spin[2]="|"
spin[3]="/"

while kill -0 $pid 2>/dev/null
do
	for i in "${spin[@]}"
	do
		echo -ne "\b\b\b${Bold}[${Green}$i${Reset}${Bold}]"
		sleep .5
	done
done
echo
tput sgr0
}

#####    HELP      ########################################
HELP () {
echo -e \\n"${Bold}Guacamole Install Script Help.${Reset}"\\n
echo "${Bold}Usage:${Reset}"
echo "  $SCRIPT [options] -s		install Guacamole Silently"
echo -e "  $SCRIPT [options] -p [yes|no]	install Proxy feature"\\n
echo "${Bold}Options:${Reset}"
echo " -${Rev}a${Reset}, <string>	--Sets the root password for MariaDB. Default is ${Bold}${MYSQL_PASSWD}${Reset}."
echo " -${Rev}b${Reset}, <string>	--Sets the Guacamole DB name. Default is ${Bold}${DB_NAME}${Reset}."
echo " -${Rev}c${Reset}, <string>	--Sets the Guacamole DB username. Default is ${Bold}{DB_USER}${Reset}."
echo " -${Rev}d${Reset}, <string>	--Sets the Guacamole DB password. Default is ${Bold}${DB_PASSWD}${Reset}."
echo " -${Rev}e${Reset}, <string>	--Sets the Java KeyStore password (least 6 characters). Default is ${Bold}${JKSTORE_PASSWD}${Reset}."
echo " -${Rev}l${Reset}, <string:string>	--Sets a domain name and e-mail for the Let's Encrypt Certificate. Example ${Bold}your@email.com:guacamole.yourdomain.com${Reset}."
echo " -${Rev}s${Reset},		--Install Guacamole Silently. Default names and password are: ${Bold}guacamole${Reset}."
echo " -${Rev}p${Reset}, [yes|no]	--Install the Proxy feature (Nginx)?."
echo " -${Rev}i${Reset},		--This option launches the interactive menu. Default is ${Bold}yes${Reset}."
echo " -${Rev}h${Reset}, 		--Displays this help message and exit."
echo -e " -${Rev}v${Reset}, 		--Displays the script version information and exits."\\n
echo "${Bold}Examples:${Reset}"
echo "  * Full and no interactive install: ${Bold}$SCRIPT -a sqlpasswd -b guacadb -c guacadbuser -d guacadbpasswd -e guacakey -s -p yes -l your@email.com:guacamole.yourdomain.com${Reset}"
echo "  * Same as above but with default names and passwords: ${Bold}$SCRIPT -s -p yes -l your@email.com:guacamole.yourdomain.com${Reset}"
echo "  * Same as above but not install Nginx and not create Let's Encrypt Certificate : ${Bold}$SCRIPT -s -p no${Reset}"
echo -e "  * Only install Nginx: ${Bold}$SCRIPT -p yes${Reset}"\\n
exit 1
}

showscriptversion () {
echo -e " ${Bold}Guacamole Stable Version: ${Yellow}${GUAC_STBL_VER}${Reset} || ${Bold}Git Version: ${Yellow}${GUACA_GIT_VER}\n" && tput sgr0
echo -e " ${Bold}Install Script Build: ${Yellow}${SCRIPT_BUILD}\n" && tput sgr0
exit 2
}

while getopts a:b:c:d:e:p:l:sihv FLAG; do
  	case $FLAG in
    	a)  #set option "a"
      	MYSQL_PASSWD=$OPTARG
      	;;
    	b)  #set option "b"
      	DB_NAME=$OPTARG
      	;;
		c)  #set option "c"
      	DB_USER=$OPTARG
      	;;
    	d)  #set option "d"
      	DB_PASSWD=$OPTARG
      	;;
    	e)  #set option "e"
      	JKSTORE_PASSWD=$OPTARG
      	;;
    	p)  #set option "p"
      	INSTALL_NGINX=$OPTARG
      	if [ $INSTALL_MODE != "silent" ]; then INSTALL_MODE="proxy"; fi
      	;;
    	l)  #set option "l"      
      	while IFS=":" read -r str1 str2; do LETSENCRYPT_CERT="yes"; if [[ $str1 = *"@"* ]]; then EMAIL_NAME=$str1; DOMAIN_NAME=$str2; else EMAIL_NAME=$str2; DOMAIN_NAME=$str1; fi; done < <(echo $OPTARG)
      	;;
    	s)  #set option "s"
      	INSTALL_MODE="silent"
      	;;
    	i)  #set option "i"
      	if [ $INSTALL_MODE != "silent" ]; then INSTALL_MODE="interactive"; fi
      	;;
    	h)  #show help
      	HELP
      	;;
    	v)  #set option "v"
      	showscriptversion
      	;;
    	\?) #unrecognized option - show help
      	echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      	HELP
      	;;
  	esac
done

#####    REPOS INSTALL      ########################################
reposinstall () {
clear
echo -e "   ----====Installation====----" && tput sgr0

# Install EPEL Repo
sleep 1 | echo -e "\n${Bold}Searching for EPEL Repository...";echo -e "\nSearching for EPEL Repository..." >> $logfile  2>&1
rpm -qa | grep epel-release | tee -a $logfile
RETVAL=${PIPESTATUS[1]}
if [ $RETVAL -eq 0 ]; then
	sleep 1 | echo -ne "${Reset}EPEL is installed."; echo -ne "EPEL is installed." >> $logfile  2>&1
else
	rpm -Uvh http://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VER}.noarch.rpm >> $logfile 2>&1 &
	sleep 1 | echo -ne "${Reset}EPEL is missing. Installing...    "; echo -ne "EPEL is missing. Installing...    " >> $logfile 2>&1 | spinner
fi

# Install RPMFusion Repo
sleep 1 | echo -e "\n${Bold}Searching for RPMFusion Repository..."; echo -e "\nSearching for RPMFusion Repository..." >> $logfile  2>&1
rpm -qa | grep rpmfusion | tee -a $logfile
RETVAL=${PIPESTATUS[1]}
if [ $RETVAL -eq 0 ]; then
	sleep 1 | echo -ne "${Reset}RPMFusion is installed.\n"; echo -ne "RPMFusion is installed.\n" >> $logfile  2>&1
else
	rpm -Uvh https://download1.rpmfusion.org/free/el/rpmfusion-free-release-${MAJOR_VER}.noarch.rpm >> $logfile 2>&1 &
	sleep 1 | echo -ne "${Reset}RPMFusion is missing. Installing...    "; echo -ne "RPMFusion is missing. Installing...    " >> $logfile 2>&1 | spinner
fi

yumupdate
}

#####    YUM UPDATES    ########################################
yumupdate () {
# Enable repos needed if using RHEL
if [ $IS_RHEL = true ] ; then
	subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms" >> $logfile 2>&1 &
	echo -ne "\n${Bold}Enabling ${OS_NAME} Repos...    ${Reset}"; echo -ne "\nEnabling ${OS_NAME} Repos...    " >> $logfile 2>&1 | spinner
fi

yum update -y >> $logfile 2>&1 &
echo -ne "\n${Bold}Updating ${OS_NAME}, please wait...    "; echo -ne "\nUpdating ${OS_NAME}, please wait...    " >> $logfile 2>&1 | spinner

baseinstall
}

#####    INSTALL BASE PACKAGES    ########################################
baseinstall () {
sleep 1 | echo -e "\n${Bold}Installing Dependencies..."; echo -e "\nInstalling Dependencies..." >> $logfile  2>&1

# Install libjpeg
rpm -qa | grep libjpeg-turbo-official-${LIBJPEG_VER} | tee -a $logfile
RETVAL=${PIPESTATUS[1]} ; echo -e "rpm -qa | grep libjpeg-turbo-official-${LIBJPEG_VER} RC is: $RETVAL" >> $logfile  2>&1

if [ $RETVAL -eq 0 ]; then
	sleep 1 | echo -ne "${Reset}-libjpeg-turbo-official-${LIBJPEG_VER} is installed\n"; echo -ne "-libjpeg-turbo-official-${LIBJPEG_VER} is installed\n" >> $logfile  2>&1
else
	yum localinstall -y ${LIBJPEG_URL}${LIBJPEG_TURBO}.${MACHINE_ARCH}.rpm >> $logfile 2>&1 &
	sleep 1 | echo -ne "${Reset}-libjpeg-turbo-official-${LIBJPEG_VER} is not installed, installing...    "; echo -ne "-libjpeg-turbo-official-${LIBJPEG_VER} is not installed, installing...    " >> $logfile 2>&1 | spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum localinstall -y ${LIBJPEG_URL}${LIBJPEG_TURBO}.${MACHINE_ARCH}.rpm RC is: $RETVAL" >> $logfile  2>&1
	ln -vfs /opt/libjpeg-turbo/include/* /usr/include/ >> $logfile 2>&1
	ln -vfs /opt/libjpeg-turbo/lib??/* /usr/lib${ARCH}/ >> $logfile 2>&1
fi

# Install ffmpeg-devel
rpm -qa | grep ffmpeg-devel | tee -a $logfile
RETVAL=${PIPESTATUS[1]} ; echo -e "rpm -qa | grep ffmpeg-devel RC is: $RETVAL" >> $logfile  2>&1
if [ $RETVAL -eq 0 ]; then
	sleep 1 | echo -e "${Reset}-ffmpeg-devel is installed\n"; echo -e "-ffmpeg-devel is installed\n" >> $logfile  2>&1
else
	yum install -y ffmpeg-devel >> $logfile 2>&1 &
	sleep 1 | echo -ne "${Reset}-ffmpeg-devel is not installed, installing...    "; echo -ne "-ffmpeg-devel is not installed, installing...    " >> $logfile 2>&1 | spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum install -y ffmpeg-devel RC is: $RETVAL" >> $logfile  2>&1
fi

# Install Required Packages
yum install -y wget pv dialog gcc cairo-devel libpng-devel uuid-devel ffmpeg-devel freerdp-devel freerdp-plugins pango-devel libssh2-devel libtelnet-devel libvncserver-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel tomcat gnu-free-mono-fonts mariadb mariadb-server policycoreutils-python setroubleshoot >> $logfile 2>&1 &
sleep 1 | echo -ne "\n${Bold}Installing Required Packages...    "; echo -ne "\nInstalling Required Packages...    " >> $logfile 2>&1 | spinner
RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC is: $RETVAL" >> $logfile  2>&1

# Packages required by git
if [ $GUAC_SOURCE == "Git" ]; then
	yum install -y git libtool libwebsockets java-1.8.0-openjdk-devel >> $logfile 2>&1 &
	sleep 1 | echo -ne "\n${Bold}Installing Required Packages for git...    "; echo -ne "\nInstalling Required Packages for git...    " >> $logfile 2>&1 | spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC for git is: $RETVAL" >> $logfile  2>&1

	#Install Maven
	sleep 1 | echo -e "\n${Bold}Download and setup Apache Maven for git..."; echo -e "\nDownload and setup Apache Maven for git..." >> $logfile 2>&1
	cd /opt
	wget ${MAVEN_URL}${MAVEN_BIN} >> $logfile  2>&1
	tar -xvzf ${MAVEN_BIN} >> $logfile  2>&1
	ln -s ${MAVEN_FN} maven >> $logfile  2>&1
	export PATH=/opt/maven/bin:${PATH} >> $logfile  2>&1
	rm -rf /opt/${MAVEN_BIN} >> $logfile  2>&1
	cd ~
fi

createdirs
}

#####    CREATE DIRS    ########################################
createdirs () {
sleep 1 | echo -e "\n${Bold}Creating Directories..." | pv -qL 25; echo -e "\nCreating Directories..." >> $logfile  2>&1
rm -fr ${INSTALL_DIR} | tee -a $logfile
mkdir -v /etc/guacamole >> $logfile  2>&1
mkdir -vp ${INSTALL_DIR}{client,selinux} >> $logfile 2>&1 && cd ${INSTALL_DIR}
mkdir -vp ${LIB_DIR}{extensions,lib} >> $logfile  2>&1
mkdir -v /usr/share/tomcat/.guacamole/ >> $logfile  2>&1

downloadguac
}

#####    DOWNLOAD GUAC    ########################################
downloadguac () {
if [ $GUAC_SOURCE == "Git" ]; then
	sleep 1 | echo -e "\n${Bold}Cloning Guacamole packages from git for installation..." | pv -qL 25; echo -e "\nCloning Guacamole packages from git for installation..." >> $logfile  2>&1
	git clone ${GUAC_URL}${GUAC_SERVER} >> $logfile  2>&1
	git clone ${GUAC_URL}${GUAC_CLIENT} >> $logfile  2>&1
else
	sleep 1 | echo -e "\n${Bold}Downloading Guacamole packages for installation..." | pv -qL 25; echo -e "\nDownloading Guacamole packages for installation..." >> $logfile  2>&1
	wget "${GUAC_URL}source/${GUAC_SERVER}.tar.gz" -O ${GUAC_SERVER}.tar.gz >> $logfile  2>&1
	wget "${GUAC_URL}binary/${GUAC_CLIENT}.war" -O ${INSTALL_DIR}client/guacamole.war >> $logfile  2>&1
	wget "${GUAC_URL}binary/${GUAC_JDBC}.tar.gz" -O ${GUAC_JDBC}.tar.gz 2>&1 >> $logfile  2>&1
	
	# Decompress Guacamole Packages
	sleep 1 | echo -e "\n${Bold}Decompressing Guacamole Server Source..." | pv -qL 25; echo -e "\nDecompressing Guacamole Server Source..." >> $logfile  2>&1
	tar xzvf ${GUAC_SERVER}.tar.gz >> $logfile 2>&1 && rm -f ${GUAC_SERVER}.tar.gz >> $logfile 2>&1
	mv -v ${GUAC_SERVER} server >> $logfile 2>&1

	sleep 1 | echo -e "${Bold}Decompressing Guacamole JDBC Extension..." | pv -qL 25; echo -e "Decompressing Guacamole JDBC Extension..." >> $logfile  2>&1
	tar xzvf ${GUAC_JDBC}.tar.gz >> $logfile 2>&1 && rm -f ${GUAC_JDBC}.tar.gz >> $logfile 2>&1
	mv -v ${GUAC_JDBC} extension >> $logfile 2>&1
fi

# MySQL Connector
sleep 1 | echo -e "\n${Bold}Downloading MySQL Connector package for installation..." | pv -qL 25; echo -e "\nDownloading MySQL Connector package for installation..." >> $logfile  2>&1
wget ${MYSQL_CON_URL}${MYSQL_CON}.tar.gz 2>&1 >> $logfile  2>&1

sleep 1 | echo -e "${Bold}Decompressing MySQL Connector..." | pv -qL 25; echo -e "Decompressing MySQL Connector..." >> $logfile  2>&1
tar xzvf ${MYSQL_CON}.tar.gz >> $logfile 2>&1 && rm -f ${MYSQL_CON}.tar.gz >> $logfile 2>&1

installguacserver
}

#####    INSTALL GUAC SERVER    ########################################
installguacserver () {
if [ $GUAC_SOURCE == "Git" ]; then
	cd guacamole-server/
	autoreconf -fi >> $logfile 2>&1 &
	sleep 1 | echo -ne "\n${Bold}Guacamole Server Compile Prep...    " | pv -qL 25; echo -ne "\nGuacamole Server Compile Prep...    " >> $logfile 2>&1 | spinner
	
	# Compile Guacamole Server
	./configure --with-systemd-dir=/etc/systemd/system >> $logfile 2>&1 &
	sleep 1 | echo -ne "\n${Bold}Compiling Guacamole Server Stage 1 of 3...    " | pv -qL 25; echo -ne "\nCompiling Guacamole Server Stage 1 of 3...    " >> $logfile 2>&1 | spinner
else
	cd server

	# Compile Guacamole Server
	./configure --with-init-dir=/etc/init.d >> $logfile 2>&1 &
	sleep 1 | echo -ne "\n${Bold}Compiling Guacamole Server Stage 1 of 3...    " | pv -qL 25; echo -ne "\nCompiling Guacamole Server Stage 1 of 3...    " >> $logfile 2>&1 | spinner
fi
# Continue Compiling Server
make >> $logfile 2>&1 &
sleep 1 | echo -ne "${Bold}Compiling Guacamole Server Stage 2 of 3...    " | pv -qL 25; echo -ne "Compiling Guacamole Server Stage 2 of 3...    " >> $logfile 2>&1 | spinner
sleep 1 && make install >> $logfile 2>&1 &
sleep 1 | echo -ne "${Bold}Compiling Guacamole Server Stage 3 of 3...    " | pv -qL 25; echo -ne "Compiling Guacamole Server Stage 3 of 3...    " >> $logfile 2>&1 | spinner
sleep 1 && ldconfig >> $logfile 2>&1 &
sleep 1 | echo -ne "${Bold}Compiling Guacamole Server Complete...    ${Reset}" | pv -qL 25; echo -ne "Compiling Guacamole Server Complete...    " >> $logfile 2>&1 | spinner
cd ..

installguacclient
}

#####    INSTALL GUAC CLIENT    ########################################
installguacclient () {
if [ $GUAC_SOURCE == "Git" ]; then
	cd guacamole-client/
	mvn package >> $logfile 2>&1 &
	sleep 1 | echo -ne "\n${Bold}Compiling Guacamole Client...    " | pv -qL 25; echo -ne "\nCompiling Guacamole Client...    " >> $logfile  2>&1 | spinner
	sleep 1 | echo -e "\n${Bold}Copying Guacamole Client..." | pv -qL 25; echo -e "\nCopying Guacamole Client..." >> $logfile  2>&1
	mv -v guacamole/target/guacamole-${GUAC_VER}.war ${LIB_DIR}guacamole.war >> $logfile 2>&1
	cd ..
else
	sleep 1 | echo -e "\n${Bold}Copying Guacamole Client..." | pv -qL 25; echo -e "\nCopying Guacamole Client..." >> $logfile  2>&1
	mv -v client/guacamole.war ${LIB_DIR}guacamole.war >> $logfile 2>&1
fi

finishguac
}

#####    FINALIZE GUAC    ########################################
finishguac () {
# Generate Guacamole Configuration File
sleep 1 | echo -e "\n${Bold}Generating Guacamole configuration file..." | pv -qL 25; echo -e "\nGenerating Guacamole configuration file..." >> $logfile  2>&1
echo "# Hostname and port of guacamole proxy
guacd-hostname: ${GUACSERVER_HOSTNAME}
guacd-port:     ${GUAC_PORT}

# MySQL properties
mysql-hostname: ${GUACSERVER_HOSTNAME}
mysql-port: ${MYSQL_PORT}
mysql-database: ${DB_NAME}
mysql-username: ${DB_USER}
mysql-password: ${DB_PASSWD}
mysql-default-max-connections-per-user: 0
mysql-default-max-group-connections-per-user: 0" > /etc/guacamole/${GUAC_CONF}

# Create Required Symlinks for Guacamole
sleep 1 | echo -e "\n${Bold}Making Guacamole symbolic links..." | pv -qL 25; echo -e "\nMaking Guacamole symbolic links..." >> $logfile  2>&1
ln -vfs ${LIB_DIR}guacamole.war /var/lib/tomcat/webapps >> $logfile  2>&1 || exit 1
ln -vfs /etc/guacamole/${GUAC_CONF} /usr/share/tomcat/.guacamole/ >> $logfile  2>&1 || exit 1
ln -vfs ${LIB_DIR}lib/ /usr/share/tomcat/.guacamole/ >> $logfile  2>&1 || exit 1
ln -vfs ${LIB_DIR}extensions/ /usr/share/tomcat/.guacamole/ >> $logfile  2>&1 || exit 1
ln -vfs /usr/local/lib/freerdp/guac* /usr/lib${ARCH}/freerdp >> $logfile  2>&1 || exit 1

# Install Default Extensions
sleep 1 | echo -e "\n${Bold}Copying Guacamole JDBC Extension to Extensions Dir..." | pv -qL 25; echo -e "\nCopying Guacamole JDBC Extension to Extensions Dir..." >> $logfile  2>&1

if [ $GUAC_SOURCE == "Git" ]; then
	# Get JDBC from compiled client
	find ./guacamole-client/extensions -name "guacamole-auth-jdbc-mysql-${GUAC_VER}.jar" -exec mv -v {} ${LIB_DIR}extensions/ \; >> $logfile  2>&1
else
	# Copy JDBC from download
	mv -v extension/mysql/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar ${LIB_DIR}extensions/ >> $logfile  2>&1 || exit 1
fi

# Copy MySQL Connector
sleep 1 | echo -e "${Bold}Copying MySQL Connector to Lib Dir..." | pv -qL 25; echo -e "Copying MySQL Connector to Lib Dir..." >> $logfile  2>&1
mv -v ${MYSQL_CON}/${MYSQL_CON}.jar ${LIB_DIR}lib/ >> $logfile  2>&1 || exit 1

appconfigs
}

#####    DATABASE/TOMCAT/JKS SETUP    ########################################
appconfigs () {
# Enable/Start MariaDB/MySQL Service
sleep 1 | echo -e "\n${Bold}Enable & Start MariaDB Service..." | pv -qL 25; echo -e "\nEnable & Start MariaDB Service..." >> $logfile  2>&1
systemctl enable mariadb.service >> $logfile  2>&1
systemctl restart mariadb.service >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}Setting Root Password for MariaDB..." | pv -qL 25; echo -e "\nSetting Root Password for MariaDB..." >> $logfile  2>&1

# Set MariaDB/MySQL Root Password
mysqladmin -u root password ${MYSQL_PASSWD} | tee -a $logfile || exit 1

# Run MariaDB/MySQL Secure Install
sleep 1 | echo -e "\n${Bold}Harden MariaDB...${Reset}" | pv -qL 25; echo -e "\nHarden MariaDB..." >> $logfile  2>&1
mysql_secure_installation <<EOF
${MYSQL_PASSWD}
n
y
y
y
y
EOF

# Create Database and user
sleep 1 | echo -e "\n${Bold}Creating Database & User for Guacamole..." | pv -qL 25; echo -e "\nCreating Database & User for Guacamole..." >> $logfile  2>&1
mysql -u root -p${MYSQL_PASSWD} -e "CREATE DATABASE ${DB_NAME};" >> $logfile  2>&1 || exit 1
mysql -u root -p${MYSQL_PASSWD} -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWD}';" >> $logfile  2>&1 || exit 1
mysql -u root -p${MYSQL_PASSWD} -e "FLUSH PRIVILEGES;" >> $logfile  2>&1 || exit 1

# Create Guacamole Table
if [ $GUAC_SOURCE == "Git" ]; then
	sleep 1 | echo -e "\n${Bold}Creating Guacamole Tables..." | pv -qL 25; echo -e "\nCreating Guacamole Tables..." >> $logfile  2>&1
	cat guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/schema/*.sql | mysql -u root -p${MYSQL_PASSWD} -D ${DB_NAME} >> $logfile  2>&1
else
	sleep 1 | echo -e "\n${Bold}Creating Guacamole Tables..." | pv -qL 25; echo -e "\nCreating Guacamole Tables..." >> $logfile  2>&1
	cat extension/mysql/schema/*.sql | mysql -u root -p${MYSQL_PASSWD} -D ${DB_NAME} >> $logfile  2>&1
fi

# Setup Tomcat
sleep 1 | echo -e "\n${Bold}Setup Tomcat Server..." | pv -qL 25; echo -e "\nSetup Tomcat Server..." >> $logfile  2>&1
sed -i '72i URIEncoding="UTF-8"' /etc/tomcat/server.xml
sed -i '92i <Connector port="8443" protocol="HTTP/1.1" SSLEnabled="true" \
               maxThreads="150" scheme="https" secure="true" \
               clientAuth="false" sslProtocol="TLS" \
               keystoreFile="/var/lib/tomcat/webapps/.keystore" \
               keystorePass="JKSTORE_PASSWD" \
               URIEncoding="UTF-8" />' /etc/tomcat/server.xml
sed -i "s/JKSTORE_PASSWD/${JKSTORE_PASSWD}/g" /etc/tomcat/server.xml

# Java KeyStore Setup
if [ $INSTALL_MODE = "silent" ]; then
	sleep 1 | echo -e "\n${Bold}Generating the Java KeyStore" | pv -qL 25; echo -e "\nGenerating the Java KeyStore" >> $logfile  2>&1
	noprompt="-noprompt -dname CN=,OU=,O=,L=,S=,C="
else
	sleep 1 | echo -e "\n${Bold}Please complete the Wizard for the Java KeyStore${Reset}" | pv -qL 25; echo -e "\nPlease complete the Wizard for the Java KeyStore" >> $logfile  2>&1
fi
keytool -genkey -alias Guacamole -keyalg RSA -keysize ${JKSTORE_KEY_SIZE} -keystore /var/lib/tomcat/webapps/.keystore -storepass ${JKSTORE_PASSWD} -keypass ${JKSTORE_PASSWD} ${noprompt} | tee -a $logfile

# Enable/Start Tomcat and Guacamole Services
sleep 1 | echo -e "\n${Bold}Enable & Start Tomcat and Guacamole Service..." | pv -qL 25; echo -e "\nEnable & Start Tomcat and Guacamole Service..." >> $logfile  2>&1
systemctl enable tomcat >> $logfile  2>&1
systemctl start tomcat >> $logfile  2>&1
systemctl enable guacd >> $logfile  2>&1
systemctl start guacd >> $logfile  2>&1
}

#####    LDAP SETUP    ########################################
ldapsetup () {

# Append LDAP configuration lines to guacamole.properties
sleep 1 | echo -e "\n${Bold}Updating Guacamole configuration file for LDAP..." | pv -qL 25; echo -e "\nUpdating Guacamole configuration file for LDAP..." >> $logfile  2>&1
echo "
# LDAP properties
ldap-hostname: ${LDAP_HOSTNAME}
ldap-port: ${LDAP_PORT}" >> /etc/guacamole/${GUAC_CONF}

if [ $SECURE_LDAP == "yes" ]; then
	KS_PATH=$(find "/usr/lib/jvm/" -name "cacerts")
	keytool -importcert -alias "ldaps" -keystore ${KS_PATH} -storepass ${CA_PASSWD} -file ${LDAPS_CERT_FULL} -noprompt >> $logfile  2>&1 &
	sleep 1 | echo -ne "${Reset}-Updating Guacamole configuration file for LDAPS...    " | pv -qL 25; echo -ne "Updating Guacamole configuration file for LDAPS...    " >> $logfile  2>&1 | spinner

	echo "ldap-encryption-method: ssl" >> /etc/guacamole/${GUAC_CONF}
fi

echo "ldap-user-base-dn: ${LDAP_BASE_DN}
ldap-search-bind-dn: ${LDAP_BIND_DN}
ldap-search-bind-password: ${LDAP_BIND_PW}
ldap-username-attribute: ${LDAP_UNAME_ATTR}" >> /etc/guacamole/${GUAC_CONF}

if [ $GUAC_SOURCE == "Git" ]; then
	# Copy LDAP Extension to Extensions Directory
	sleep 1 | echo -e "${Bold}Copying Guacamole LDAP Extension to Extensions Dir..." | pv -qL 25; echo -e "Copying Guacamole LDAP Extension to Extensions Dir..." >> $logfile  2>&1
	find ./guacamole-client/extensions -name "${GUAC_LDAP}.jar" -exec mv -v {} ${LIB_DIR}extensions/ \; >> $logfile  2>&1
else
	# Download LDAP Extension
	sleep 1 | echo -e "${Bold}Downloading LDAP Extension..." | pv -qL 25; echo -e "Downloading LDAP Extension..." >> $logfile  2>&1
	wget "${GUAC_URL}binary/${GUAC_LDAP}.tar.gz" -O ${GUAC_LDAP}.tar.gz >> $logfile  2>&1

	# Decompress LDAP Extension
	sleep 1 | echo -e "${Bold}Decompressing Guacamole LDAP Extension..." | pv -qL 25; echo -e "Decompressing Guacamole LDAP Extension..." >> $logfile  2>&1
	tar xzvf ${GUAC_LDAP}.tar.gz >> $logfile  2>&1 && rm -f ${GUAC_LDAP}.tar.gz >> $logfile  2>&1
	mv ${GUAC_LDAP} extension >> $logfile  2>&1

	# Copy LDAP Extension to Extensions Directory
	sleep 1 | echo -e "${Bold}Copying Guacamole LDAP Extension to Extensions Dir..." | pv -qL 25; echo -e "Copying Guacamole LDAP Extension to Extensions Dir..." >> $logfile  2>&1
	mv -v extension/${GUAC_LDAP}/${GUAC_LDAP}.jar ${LIB_DIR}extensions/ >> $logfile  2>&1 || exit 1
fi
}

#####    CUSTOM EXTENSION SETUP    ########################################
custsetup () {
# Copy Custom Extension to Extensions Directory
sleep 1 | echo -e "\n${Bold}Copying Custom Guacamole Extension to Extensions Dir..." | pv -qL 25; echo -e "\nCopying Custom Guacamole Extension to Extensions Dir..." >> $logfile  2>&1
mv -v ${CUST_FULL} ${LIB_DIR}extensions/ >> $logfile  2>&1 || exit 1
}

#####    NGINX INSTALL    ########################################
nginxinstall ()
{
# Install Nginx Repo
sleep 1 | echo -e "\n${Bold}Installing Nginx repository..."; echo -e "\nInstalling Nginx repository..." >> $logfile  2>&1
echo "[nginx]
name=nginx repo
baseurl=${NGINX_URL}
gpgcheck=0
enabled=1" > /etc/yum.repos.d/nginx.repo

yum install -y nginx pv >> $logfile  2>&1 &
sleep 1 | echo -ne "${Bold}Installing Nginx...    "; echo -ne "Installing Nginx...    " >> $logfile 2>&1 | spinner
RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC is: $RETVAL" >> $logfile  2>&1

# Backup Nginx Configuration
sleep 1 | echo -e "${Reset}-Making Nginx Config Backup..." | pv -qL 25; echo -e "-Making Nginx Config Backup..." >> $logfile  2>&1
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.ori.bkp >> $logfile  2>&1

# Generate Nginx Conf's
#sleep 1 | echo -e "${Reset}-Generating Nginx Configurations..." | pv -qL 25; echo -e "-Generating Nginx Configurations..." >> $logfile  2>&1

# HTTP Nginx Conf
echo "server {
	listen 80 default_server;
	listen [::]:80 default_server;
        server_name ${DOMAIN_NAME};
	return 301 https://\$host\$request_uri;

	#location ${GUAC_URIPATH} {
   	proxy_pass http://${GUACSERVER_HOSTNAME}:8080/guacamole/;
    	proxy_buffering off;
    	proxy_http_version 1.1;
    	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    	proxy_set_header Upgrade \$http_upgrade;
    	proxy_set_header Connection \$http_connection;
    	proxy_cookie_path /guacamole/ ${GUAC_URIPATH};
    	access_log off;
	}
}" > /etc/nginx/conf.d/guacamole.conf

# Base HTTPS/SSL Nginx Conf
#echo 'server {
#	listen              443 ssl http2;
#	listen				[::]:443 ssl http2;
#	server_name         localhost;
#	ssl_certificate     guacamole.crt;
#	ssl_certificate_key guacamole.key;
#	ssl_protocols       TLSv1.3 TLSv1.2;' > /etc/nginx/conf.d/guacamole_ssl.conf

# More Secure SSL Nginx Parameters (If selected)
#if [ $NGINX_HARDEN = "yes" ]; then
#	echo "	ssl_ciphers         'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
#	ssl_ecdh_curve		secp521r1:secp384r1:prime256v1;
#    ssl_prefer_server_ciphers		on;
#    ssl_session_cache		shared:SSL:10m;
#    ssl_session_timeout		1d;
#    ssl_session_tickets		off;
#    add_header		Strict-Transport-Security \"max-age=15768000; includeSubDomains\" always;
#    add_header		X-Frame-Options DENY;
#    add_header		X-Content-Type-Options nosniff;
#    add_header		X-XSS-Protection \"1; mode=block\";" >> /etc/nginx/conf.d/guacamole_ssl.conf

# Generate dhparam and append to Nginx SSL Conf for Forward Secrecy(If selected)
#	if [ $DHE_USE = "yes" ]; then
#		openssl dhparam -out dhparam.pem ${DHE_KEY_SIZE} >> $logfile  2>&1 &
#		sleep 1 | echo -ne "\n${Bold}Generating DHE Key, this may take a long time...    " | pv -qL 25; echo -ne "\nGenerating DHE Key, this may take a long time...    " >> $logfile 2>&1 | spinner
#		mv dhparam.pem /etc/ssl/certs >> $logfile 2>&1
#		echo '	ssl_dhparam			/etc/ssl/certs/dhparam.pem;' >> /etc/nginx/conf.d/guacamole_ssl.conf
#	fi	
#else # Generic SSL Nginx Parameters
#	echo 'ssl_ciphers		HIGH:!aNULL:!MD5;' >> /etc/nginx/conf.d/guacamole_ssl.conf
#fi

# Append the rest of the SSL Nginx Conf
#echo "	
#	location ${GUAC_URIPATH} {
#		proxy_pass http://${GUACSERVER_HOSTNAME}:8080/guacamole/;
#		proxy_buffering off;
#		proxy_http_version 1.1;
#		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#		proxy_set_header Upgrade \$http_upgrade;
#		proxy_set_header Connection \$http_connection;
#		proxy_cookie_path /guacamole/ ${GUAC_URIPATH};
#		access_log off;
 #   }
#}" >> /etc/nginx/conf.d/guacamole_ssl.conf

# Lets Encrypt Setup (If selected)
#if [ $LETSENCRYPT_CERT = "yes" ]; then
	yum install -y certbot python2-certbot-nginx >> $logfile 2>&1 &
	sleep 1 | echo -e "\n${Bold}Downloading certboot tool...\n" | pv -qL 25; echo -e "\nDownloading certboot tool...\n" >> $logfile 2>&1 | spinner
	#wget -q https://dl.eff.org/certbot-auto -O /usr/bin/certbot-auto | tee -a $logfile
	#sleep 1 | echo -e "\n${Bold}Changing permissions to certboot...\n" | pv -qL 25; echo -e "\nChanging permissions to certboot...\n" >> $logfile  2>&1
	#chmod a+x /usr/bin/certbot-auto >> $logfile 2>&1
	#sleep 1 | echo -e "\n${Bold}Generating a ${CERTYPE} SSL Certificate...\n" | pv -qL 25; echo -e "\nGenerating a ${CERTYPE} SSL Certificate...\n" >> $logfile  2>&1
	#certbot --nginx -n --agree-tos --redirect --hsts --must-staple --staple-ocsp --preferred-challenges tls-sni --rsa-key-size ${LE_KEY_SIZE} -m "${EMAIL_NAME}" -d "${DOMAIN_NAME}" | tee -a $logfile
	#certbot-auto certonly -n --agree-tos --standalone --preferred-challenges tls-sni --rsa-key-size ${LE_KEY_SIZE} -m "${EMAIL_NAME}" -d "${DOMAIN_NAME}" | tee -a $logfile
	#ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" /etc/nginx/guacamole.crt || true >> $logfile 2>&1
	#ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem" /etc/nginx/guacamole.key || true >> $logfile 2>&1
#else # Use a Self-Signed Cert
#	if [ $INSTALL_MODE = "silent" ]; then
#		sleep 1 | echo -e "\n${Bold}Generating a ${CERTYPE} SSL Certificate...\n" | pv -qL 25; echo -e "\nGenerating a ${CERTYPE} SSL Certificate...\n" >> $logfile  2>&1
#		subj="-subj /C=XX/ST=/L=City/O=Company/CN=/"
#	else
#		sleep 1 | echo -e "\n${Bold}Please complete the Wizard for the ${CERTYPE} SSL Certificate...${Reset}" | pv -qL 25; echo -e "\nPlease complete the Wizard for the ${CERTYPE} SSL Certificate..." >> $logfile  2>&1
#	fi
#	openssl req -x509 -sha512 -nodes -days 365 -newkey rsa:${SSL_KEY_SIZE} -keyout /etc/nginx/guacamole.key -out /etc/nginx/guacamole.crt ${subj} | tee -a $logfile
#fi

sleep 1 | echo -e "${Bold}\nIf you need to understand the Nginx configurations please go to:\n ${Green} http://nginx.org/en/docs/ \n${Reset}${Bold}If you need to replace the certificate file please read first:\n ${Green} http://nginx.org/en/docs/http/configuring_https_servers.html ${Reset}"; echo -e "\nIf you need to understand the Nginx configurations please go to:\n  http://nginx.org/en/docs/ \nIf you need to replace the certificate file please read first:\n  http://nginx.org/en/docs/http/configuring_https_servers.html" >> $logfile  2>&1
}

#####    SELINUX SETTINGS    ########################################
selinuxsettings ()
{
sleep 1 | echo -e "\n${Bold}Setting SELinux Context..." | pv -qL 25; echo -e "\nSetting SELinux Context..." >> $logfile  2>&1

# Set Booleans
setsebool -P httpd_can_network_connect 1 >> $logfile  2>&1
setsebool -P httpd_can_network_relay 1 >> $logfile  2>&1
setsebool -P tomcat_can_network_connect_db 1 >> $logfile  2>&1

# Guacamole Client Context
semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}guacamole.war" >> $logfile  2>&1
restorecon -v "${LIB_DIR}guacamole.war" >> $logfile  2>&1

# Guacamole JDBC Extension Context
semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar" >> $logfile  2>&1
restorecon -v "${LIB_DIR}extensions/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar" >> $logfile  2>&1

# Guacamole LDAP Extension Context (If selected)
if [ $INSTALL_LDAP = "yes" ]; then
	semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole Custom Extension Context (If selected)
if [ $INSTALL_CUST = "yes" ]; then
	semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${CUST_FN}" >> $logfile  2>&1
	restorecon -v "${LIB_DIR}extensions/${CUST_FN}" >> $logfile  2>&1
fi

# MySQL Connector Extension Context
semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}lib/${MYSQL_CON}.jar" >> $logfile  2>&1
restorecon -v "${LIB_DIR}lib/${MYSQL_CON}.jar" >> $logfile  2>&1

sestatus >> $logfile 2>&1
}

#####    FIREWALL SETTINGS    ########################################
firewallsetting () {
sleep 1 | echo -e "\n${Bold}Setting Firewall..." | pv -qL 25; echo -e "\nSetting Firewall..." >> $logfile  2>&1
echo -e "Take Firewall RC...\n" >> $logfile  2>&1
echo -e "rpm -qa | grep firewalld" >> $logfile  2>&1
rpm -qa | grep firewalld >> $logfile  2>&1
RETVALqaf=$?
echo -e "\nservice firewalld status" >> $logfile  2>&1
service firewalld status >> $logfile  2>&1
RETVALsf=$?

if [ $RETVALsf -eq 0 ]; then
	sleep 1 | echo -e "${Reset}-firewalld is installed and started on the system" | pv -qL 25; echo -e "...firewalld is installed and started on the system" >> $logfile  2>&1
elif [ $RETVALqaf -eq 0 ]; then
	sleep 1 | echo -e "${Reset}-firewalld is installed but not enabled or started on the system" | pv -qL 25; echo -e "-firewalld is installed but not enabled or started on the system" >> $logfile  2>&1
     systemctl enable firewalld
     systemctl start firewalld
fi
firewallD
}

#####    FIREWALLD    ########################################
firewallD () {
echo -e "\nMaking Firewall Backup...\ncp /etc/firewalld/zones/public.xml $fwbkpfile" >> $logfile  2>&1
cp /etc/firewalld/zones/public.xml $fwbkpfile >> $logfile 2>&1

sleep 1 | echo -e "${Reset}-Opening ports 80 and 443" | pv -qL 25; echo -e "-Opening ports 80 and 443" >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=http" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-service=http >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=https" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-service=https >> $logfile  2>&1

if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then
    sleep 1 | echo -e "${Reset}-Opening ports 8080 and 8443" | pv -qL 25; echo -e "-Opening ports 8080 and 8443" >> $logfile  2>&1
    echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8080/tcp" >> $logfile  2>&1
    firewall-cmd --permanent --zone=public --add-port=8080/tcp >> $logfile  2>&1
    echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8443/tcp" >> $logfile  2>&1
    firewall-cmd --permanent --zone=public --add-port=8443/tcp >> $logfile  2>&1
    echo -e "Reload firewall...\nfirewall-cmd --reload\n" >> $logfile  2>&1
fi
firewall-cmd --reload >> $logfile  2>&1
}

#####    COMPLETION MESSAGES    ########################################
showmessages () {
# Enable/Start Nginx Service
sleep 1 | echo -e "\n${Bold}Enable & Start Nginx Service..." | pv -qL 25; echo -e "\nEnable & Start Nginx Service..." >> $logfile  2>&1
systemctl enable nginx.service >> $logfile 2>&1 || exit 1
systemctl start nginx.service >> $logfile 2>&1 || exit 1

sleep 1 | echo -e "\n${Bold}Restarting all services" | pv -qL 25; echo -e "\nRestarting all services" >> $logfile  2>&1

systemctl restart tomcat >> $logfile 2>&1 || exit 1
systemctl restart guacd >> $logfile 2>&1 || exit 1
systemctl restart mariadb >> $logfile 2>&1 || exit 1
systemctl restart nginx >> $logfile 2>&1 || exit 1

sleep 1 | echo -e "\n${Bold}Finished Successfully" | pv -qL 25; echo -e "\nFinished Successfully" >> $logfile  2>&1
sleep 1 | echo -e "${Reset}You can check the log file at ${logfile}" | pv -qL 25; echo -e "You can check the log file at ${logfile}" >> $logfile  2>&1
sleep 1 | echo -e "${Reset}Your firewall backup file at ${fwbkpfile}"; echo -e "Your firewall backup file at ${fwbkpfile}" >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}To manage Guacamole go to http://${GUACSERVER_HOSTNAME}${GUAC_URIPATH} or https://${GUACSERVER_HOSTNAME}${GUAC_URIPATH}"; echo -e "\nTo manage Guacamole go to http://${GUACSERVER_HOSTNAME}${GUAC_URIPATH} or https://${GUACSERVER_HOSTNAME}${GUAC_URIPATH}" >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}The default username and password are: ${Red}guacadmin${Reset}"; echo -e "\nThe default username and password are: guacadmin" >> $logfile  2>&1
sleep 1 | echo -e "${Red}Its highly recommended to create an admin account in Guacamole and disable/delete the default asap!${Reset}"; echo -e "Its highly recommended to create an admin account in Guacamole and disable/delete the default asap!" >> $logfile  2>&1
sleep 1 | echo -e "\n${Green}While not required, you may consider a reboot after verifying install${Reset}" | pv -qL 25; echo -e "\nWhile not required, you may consider a reboot after verifying install" >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}Contact ${ADM_POC} with any questions or concerns regarding this script\n"; echo -e "\nContact ${ADM_POC} with any questions or concerns regarding this script\n" >> $logfile  2>&1
tput sgr0
}

#####    START    ########################################
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then init_vars; fi
if [[ $INSTALL_MODE = "interactive"  &&  $INSTALL_MODE != "silent" && $INSTALL_MODE != "proxy" ]] ; then src_menu; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then src_vars; fi
if [[ $INSTALL_MODE = "interactive"  &&  $INSTALL_MODE != "silent" && $INSTALL_MODE != "proxy" ]] ; then install_menu; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then reposinstall; fi
if [ $INSTALL_LDAP = "yes" ]; then ldapsetup; fi
if [ $INSTALL_CUST = "yes" ]; then custsetup; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then nginxinstall; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then selinuxsettings; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then firewallsetting; fi
if [ $INSTALL_MODE = "interactive" ] || [ $INSTALL_MODE = "silent" ]; then showmessages; fi
