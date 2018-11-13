#!/bin/env bash
#####    UNIVERSAL VARS    ##########
# USER CONFIGURABLE        #
# Generic
SCRIPT_BUILD="2018_11_09" # Scripts Date for last modified as "yyyy_mm_dd"
ADM_POC="Local Admin, admin@admin.com"  # Point of contact for the Guac server admin

# Versions
GUAC_STBL_VER="0.9.14"
MYSQL_CON_VER="8.0.13"
LIBJPEG_VER="2.0.0"

# Ports
GUAC_PORT="4822"
MYSQL_CON_PORT="3306"

# Key Sizes
JKSTORE_KEY_SIZE="4096" # Default Java Keystore key-size
LE_KEY_SIZE="4096" # Default Let's Encrypt key-size
SSL_KEY_SIZE="4096" # Default Self-signed SSL key-size
DHE_KEY_SIZE="2048" # Default DHE/Forward Secrecy key-size

# Default Credentials
MYSQL_PASSWD_DEF="guacamole" # Default MySQL/MariaDB root password
DB_NAME_DEF="guac_db" # Defualt database name
DB_USER_DEF="guac_adm" # Defualt database user name
DB_PASSWD_DEF="guacamole" # Defualt database password
JKSTORE_PASSWD_DEF="guacamole" # Default Java Keystore password

# ONLY CAHNGE IF NOT WORKING #
# URLS
MYSQ_CON_URL="http://dev.mysql.com/get/Downloads/Connector-J/" #Direct URL for download
LIBJPEG_URL="http://sourceforge.net/projects/libjpeg-turbo/files/${LIBJPEG_VER}/" #libjpeg download path

# Dirs and File Names
LIB_DIR="/var/lib/guacamole/"
GUACA_CONF="guacamole.properties"
MYSQL_CONNECTOR="mysql-connector-java-${MYSQL_CON_VER}"
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
##### END UNIVERSAL VARS   ##########

#####    INITIALIZE COMMON VARS    ##########
init_vars () {
# ONLY CAHNGE IF NOT WORKING #
GUAC_GIT_VER=`curl -s https://raw.githubusercontent.com/apache/guacamole-server/master/configure.ac | grep 'AC_INIT([guacamole-server]*' | awk -F'[][]' -v n=2 '{ print $(2*n) }'`
PWD=`pwd`
REGEX_MAIL="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
REGEX_IDN="(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)"

# Determine if OS is RHEL or not (otherwise assume CentOS)
if rpm -q subscription-manager 2>&1 > /dev/null; then IS_RHEL=true; else IS_RHEL=false; fi

MAJOR_VER=`cat /etc/redhat-release | grep -oP "[0-9]+" | head -1` # Return 5, 6 or 7 when OS is 5.x, 6.x or 7.x

#Set arch used in some paths
MACHINE_ARCH=`uname -m`
if [ $MACHINE_ARCH="x86_64" ]; then ARCH="64"; elif [ $MACHINE_ARCH="i686" ]; then MACHINE_ARCH="i386"; else ARCH=""; fi

# Set OS Name to RHEL or CentOS
if [ $IS_RHEL = true ]; then OS_NAME="RHEL"; else OS_NAME="CentOS"; fi

OS_NAME_L="$(echo $OS_NAME | tr '[:upper:]' '[:lower:]')" # Set lower case rhel or centos for use in some URLs

NGINX_URL=http://nginx.org/packages/$OS_NAME_L/$MAJOR_VER/$MACHINE_ARCH/ # Set nginx url for RHEL or CentOS

#Set SQL package names
if [ $MAJOR_VER -ge 7 ]; then MySQL_Packages="mariadb mariadb-server"; Menu_SQL="MariaDB"; else MySQL_Packages="mysql mysql-server"; Menu_SQL="MySQL"; fi
}

#####      SOURCE MENU       ##########
srcmenu () {
clear

echo -e "   ----====Installation Menu====----\n   ${Bold}Guacamole Remote Desktop Gateway" && tput sgr0
echo -e "   ${Bold}OS: ${Yellow}${OS_NAME} ${MAJOR_VER} ${MACHINE_ARCH}\n" && tput sgr0
echo -e "   ${Bold}Stable Version: ${Yellow}${GUACA_VER}${Reset} || ${Bold}Git Version: ${Yellow}${GUACA_GIT_VER}\n" && tput sgr0

while true; do
  read -p "${Green} Pick the desired source to install from (enter 'stable' or 'git', default is 'stable'): ${Yellow}" GUACA_SOURCE
  case $GUAC_SOURCE in
      Stable|stable|"") GUAC_SOURCE="stable"; break;;
	  Git|git|GIT) GUAC_SOURCE="git"; break;;
	  * ) echo "${Green} Please enter 'stable' or 'git' to select source/version (without quotes)";;
  esac
done

if [ $GUAC_SOURCE == "git" ]; then
  GUAC_VER=${GUAC_GIT_VER}
else
  GUAC_VER=${GUAC_STBL_VER}
fi

INSTALL_DIR="/usr/local/src/guacamole/${GUAC_VER}/"
filename="${PWD}/guacamole-${GUACA_VER}_"$(date +"%d-%y-%b")""
logfile="${filename}.log"
fwbkpfile="${filename}.firewall.bkp" # Firewall backup file name

tput sgr0
}