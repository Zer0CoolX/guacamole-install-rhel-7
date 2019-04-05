#!/bin/env bash
#####    NOTES             ###################################
# Project Page: https://github.com/Zer0CoolX/guacamole-install-rhel
# Licence (GPL-3.0): https://github.com/Zer0CoolX/guacamole-install-rhel/blob/master/LICENSE
# Report Issues: https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/How-to-Report-Issues-(Bugs,-Feature-Request-and-Help)
# Wiki: https://github.com/Zer0CoolX/guacamole-install-rhel/wiki
#
# WARNING: For use on RHEL/CentOS 7.x and up only.
#	-Use at your own risk!  
#	-Use only for new installations of Guacamole!
# 	-Read all documentation (wiki) prior to using this script!
#	-Test prior to deploying on a production system!
#
##### CHECK FOR SUDO or ROOT ##################################
if ! [ $(id -u) = 0 ]; then echo "This script must be run as sudo or root, try again..."; exit 1 ; fi

##########################################################
#####      VARIABLEs   ###################################
##########################################################

#####    UNIVERSAL VARS    ###################################
# USER CONFIGURABLE        #
# Generic
SCRIPT_BUILD="2019_4_4" # Scripts Date for last modified as "yyyy_mm_dd"
ADM_POC="Local Admin, admin@admin.com"  # Point of contact for the Guac server admin

# Versions
GUAC_STBL_VER="1.0.0" # Latest stable version of Guac from https://guacamole.apache.org/releases/
MYSQL_CON_VER="5.1.47" # Working stable release of MySQL Connecter J
LIBJPEG_VER="2.0.2" # Latest stable version of libjpeg-turbo
MAVEN_VER="3.6.0" # Latest stable version of Apache Maven

# Ports
GUAC_PORT="4822"
MYSQL_PORT="3306"

# Key Sizes
JKSTORE_KEY_SIZE_DEF="4096" # Default Java Keystore key-size
LE_KEY_SIZE_DEF="4096" # Default Let's Encrypt key-size
SSL_KEY_SIZE_DEF="4096" # Default Self-signed SSL key-size

# SSL Certificate default type
SSL_CERT_TYPE="Self-signed"

# Nginx defualt security level
NGINX_SEC=false

# Default Credentials
MYSQL_PASSWD_DEF="guacamole" # Default MySQL/MariaDB root password
DB_NAME_DEF="guac_db" # Defualt database name
DB_USER_DEF="guac_adm" # Defualt database user name
DB_PASSWD_DEF="guacamole" # Defualt database password
JKS_GUAC_PASSWD_DEF="guacamole" # Default Java Keystore password
JKS_CACERT_PASSWD_DEF="guacamole" # Default CACert Java Keystore password, used with LDAPS

# Misc
GUAC_URIPATH_DEF="/" # Default URI for Guacamole
DOMAIN_NAME_DEF="localhost" # Default domain name of server

# ONLY CAHNGE IF NOT WORKING #
# URLS
MYSQL_CON_URL="https://dev.mysql.com/get/Downloads/Connector-J/" #Direct URL for download
LIBJPEG_URL="https://sourceforge.net/projects/libjpeg-turbo/files/${LIBJPEG_VER}/" #libjpeg download path

# Dirs and File Names
LIB_DIR="/var/lib/guacamole/"
GUAC_CONF="guacamole.properties" # Guacamole configuration/properties file
MYSQL_CON="mysql-connector-java-${MYSQL_CON_VER}"
LIBJPEG_TURBO="libjpeg-turbo-official-${LIBJPEG_VER}"

# Formats
Black=`tput setaf 0`	#${Black}
Red=`tput setaf 1`	#${Red}
Green=`tput setaf 2`	#${Green}
Yellow=`tput setaf 3`	#${Yellow}
Blue=`tput setaf 4`	#${Blue}
Magenta=`tput setaf 5`	#${Magenta}
Cyan=`tput setaf 6`	#${Cyan}
White=`tput setaf 7`	#${White}
Bold=`tput bold`	#${Bold}
UndrLn=`tput sgr 0 1`	#${UndrLn}
Rev=`tput smso`		#${Rev}
Reset=`tput sgr0`	#${Reset}
##### END UNIVERSAL VARS   ###################################

#####    INITIALIZE COMMON VARS    ###################################
# ONLY CHANGE IF NOT WORKING #
init_vars () {
# Get the release version of Guacamole from/for Git
GUAC_GIT_VER=`curl -s https://raw.githubusercontent.com/apache/guacamole-server/master/configure.ac | grep 'AC_INIT([guacamole-server]*' | awk -F'[][]' -v n=2 '{ print $(2*n) }'`
PWD=`pwd` # Current directory

# Determine if OS is RHEL or not (otherwise assume CentOS)
if rpm -q subscription-manager 2>&1 > /dev/null; then OS_NAME="RHEL"; else OS_NAME="CentOS"; fi
OS_NAME_L="$(echo $OS_NAME | tr '[:upper:]' '[:lower:]')" # Set lower case rhel or centos for use in some URLs

# Get OS major version, used in some paths/vars that require it
MAJOR_VER=`cat /etc/redhat-release | grep -oP "[0-9]+" | head -1` # Return 5, 6 or 7 when OS is 5.x, 6.x or 7.x

#Set arch used in some paths
MACHINE_ARCH=`uname -m`
if [ $MACHINE_ARCH="x86_64" ]; then ARCH="64"; elif [ $MACHINE_ARCH="i686" ]; then MACHINE_ARCH="i386"; else ARCH=""; fi

NGINX_URL=https://nginx.org/packages/$OS_NAME_L/$MAJOR_VER/$MACHINE_ARCH/ # Set nginx url for RHEL or CentOS
}

#####      SOURCE VARIABLES       ###################################
src_vars () {
# Check if selected source is Git or stable release, set variables based on selection
if [ $GUAC_SOURCE == "Git" ]; then
	GUAC_VER=${GUAC_GIT_VER}
	GUAC_URL="git://github.com/apache/"
	GUAC_SERVER="guacamole-server.git"
	GUAC_CLIENT="guacamole-client.git"
	MAVEN_MAJOR_VER=${MAVEN_VER:0:1}
	MAVEN_URL="https://www-us.apache.org/dist/maven/maven-${MAVEN_MAJOR_VER}/${MAVEN_VER}/binaries/"
	MAVEN_FN="apache-maven-${MAVEN_VER}"
	MAVEN_BIN="${MAVEN_FN}-bin.tar.gz"
else # Stable release
	GUAC_VER=${GUAC_STBL_VER}
	GUAC_URL="https://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/"
	GUAC_SERVER="guacamole-server-${GUAC_VER}"
	GUAC_CLIENT="guacamole-${GUAC_VER}"
fi

# JDBC Extension file name
GUAC_JDBC="guacamole-auth-jdbc-${GUAC_VER}"

# LDAP extension file name
GUAC_LDAP="guacamole-auth-ldap-${GUAC_VER}"

# Dirs and file names
INSTALL_DIR="/usr/local/src/guacamole/${GUAC_VER}/" # Guacamole installation dir
FILENAME="${PWD}/guacamole-${GUAC_VER}_"$(date +"%d-%y-%b")"" # Script generated log filename
logfile="${FILENAME}.log" # Script generated log file full name
fwbkpfile="${FILENAME}.firewall.bkp" # Firewall backup file name
}

##########################################################
#####      MENUs       ###################################
##########################################################

#####      SOURCE MENU       ###################################
src_menu () {
clear

echo -e "   ${Reset}${Bold}----====Gucamole Installation Script====----\n       ${Reset}Guacamole Remote Desktop Gateway\n"
echo -e "   ${Bold}***        Source Menu     ***\n"
echo -e "   OS: ${Yellow}${OS_NAME} ${MAJOR_VER} ${MACHINE_ARCH}" && tput sgr0
echo -e "   ${Bold}Stable Version: ${Yellow}${GUAC_STBL_VER}${Reset} || ${Bold}Git Version: ${Yellow}${GUAC_GIT_VER}\n" && tput sgr0

while true; do
	read -p "${Green} Pick the desired source to install from (enter 'stable' or 'git', default is 'stable'): ${Yellow}" GUAC_SOURCE
	case $GUAC_SOURCE in
		[Ss]table|"" ) GUAC_SOURCE="Stable"; break;;
		[Gg][Ii][Tt] ) GUAC_SOURCE="Git"; break;;
		* ) echo "${Green} Please enter 'stable' or 'git' to select source/version (without quotes)";;
	esac
done

tput sgr0
}

#####    START EXECUTION   ###################################
init_vars
src_menu
src_vars

#####      MENU HEADERS       ###################################
# Called by each menu and summary menu to display the dynamic header
menu_header () {
clear

echo -e "   ${Reset}${Bold}----====Gucamole Installation Script====----\n       ${Reset}Guacamole Remote Desktop Gateway\n"
echo -e "   ${Bold}***     ${SUB_MENU_TITLE}     ***\n"
echo -e "   OS: ${Yellow}${OS_NAME} ${MAJOR_VER} ${MACHINE_ARCH}" && tput sgr0
echo -e "   ${Bold}Source/Version: ${Yellow}${GUAC_SOURCE} ${GUAC_VER}\n" && tput sgr0
}

#####      DATABASE and JKS MENU       ###################################
db_menu () {
SUB_MENU_TITLE="Database and JKS Menu"

menu_header

echo -n "${Green} Enter the Guacamole DB name (default ${DB_NAME_DEF}): ${Yellow}"
	read DB_NAME
	DB_NAME=${DB_NAME:-${DB_NAME_DEF}}
echo -n "${Green} Enter the Guacamole DB username (default ${DB_USER_DEF}): ${Yellow}"
	read DB_USER
	DB_USER=${DB_USER:-${DB_USER_DEF}}
echo -n "${Green} Enter the Java KeyStore key-size to use (default ${JKSTORE_KEY_SIZE_DEF}): ${Yellow}"
	read JKSTORE_KEY_SIZE
	JKSTORE_KEY_SIZE=${JKSTORE_KEY_SIZE:-${JKSTORE_KEY_SIZE_DEF}}

tput sgr0
}

#####      PASSWORDS MENU       ###################################
pw_menu () {
SUB_MENU_TITLE="Passwords Menu"

menu_header

echo -n "${Green} Enter the root password for MariaDB: ${Yellow}"
	read MYSQL_PASSWD
	MYSQL_PASSWD=${MYSQL_PASSWD:-${MYSQL_PASSWD_DEF}}
echo -n "${Green} Enter the Guacamole DB password: ${Yellow}"
	read DB_PASSWD
	DB_PASSWD=${DB_PASSWD:-${DB_PASSWD_DEF}}
echo -n "${Green} Enter the Guacamole Java KeyStore password, must be 6 or more characters: ${Yellow}"
	read JKS_GUAC_PASSWD
	JKS_GUAC_PASSWD=${JKS_GUAC_PASSWD:-${JKS_GUAC_PASSWD_DEF}}

tput sgr0
}

#####      SSL CERTIFICATE TYPE MENU       ###################################
ssl_cert_type_menu () {
SUB_MENU_TITLE="SSL Certificate Type Menu"

menu_header

echo -e "${Green} What kind of SSL certificate should be used?${Yellow}"
PS3="${Green} Enter the number of the desired SSL certificate type: ${Yellow}"
options=("LetsEncrypt" "Self-signed" "None")
select opt in "${options[@]}"
do
	case $opt in
		"LetsEncrypt") SSL_CERT_TYPE="LetsEncrypt"; le_menu; break;;
		"Self-signed"|"") SSL_CERT_TYPE="Self-signed"; ss_menu; break;;
		"None")
			SSL_CERT_TYPE="None"
			OCSP_USE=false
			echo -e "\n\n${Red} No SSL certificate selected. This can be configured manually at a later time."
			sleep 5
			break;;
		* ) echo "${Green} ${REPLY} is not a valid option, enter the number representing your desired cert type.";;
		esac
done

tput sgr0
}

#####      LETSENCRYPT MENU       ###################################
le_menu () {
SUB_MENU_TITLE="LetsEncrypt Menu"

menu_header

echo -n "${Green} Enter a valid e-mail for let's encrypt certificate: ${Yellow}"
	read EMAIL_NAME
echo -n "${Green} Enter the Let's Encrypt key-size to use (default ${LE_KEY_SIZE_DEF}): ${Yellow}"
	read LE_KEY_SIZE
	LE_KEY_SIZE=${LE_KEY_SIZE:-${LE_KEY_SIZE_DEF}}

while true; do
	read -p "${Green} Use OCSP Stapling (default yes): ${Yellow}" yn
	case $yn in
		[Yy]*|"" ) OCSP_USE=true; break;;
		[Nn]* ) OCSP_USE=false; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
		esac
done

tput sgr0
}

#####    SELF-SIGNED SSL CERT MENU    ########################################
ss_menu () {
OCSP_USE=false
SUB_MENU_TITLE="Self-signed SSL Certificate Menu"

menu_header

echo -n "${Green} Enter the Self-Signed SSL key-size to use (default ${SSL_KEY_SIZE_DEF}): ${Yellow}"
	read SSL_KEY_SIZE
	SSL_KEY_SIZE=${SSL_KEY_SIZE:-${SSL_KEY_SIZE_DEF}}

tput sgr0
}

#####    NGINX OPTIONS MENU    ########################################
nginx_menu () {
SUB_MENU_TITLE="Nginx Menu"

menu_header

# Server LAN IP
GUAC_LAN_IP_DEF=$(hostname -I | sed 's/ .*//')

echo -n "${Green} Enter the LAN IP of this server (default ${GUAC_LAN_IP_DEF}): ${Yellow}"
	read GUAC_LAN_IP
	GUAC_LAN_IP=${GUAC_LAN_IP:-${GUAC_LAN_IP_DEF}}
echo -n "${Green} Enter a valid hostname or public domain such as mydomain.com (default ${DOMAIN_NAME_DEF}): ${Yellow}"
	read DOMAIN_NAME
	DOMAIN_NAME=${DOMAIN_NAME:-${DOMAIN_NAME_DEF}}
echo -n "${Green} Enter the URI path, starting and ending with / for example /guacamole/ (default ${GUAC_URIPATH_DEF}): ${Yellow}"
	read GUAC_URIPATH
	GUAC_URIPATH=${GUAC_URIPATH:-${GUAC_URIPATH_DEF}}

while true; do
	read -p "${Green} Use only >= 256-bit SSL ciphers (More secure, less compatible. default: no)?: ${Yellow}" yn
	case $yn in
		[Yy]* ) NGINX_SEC=true; break;;
		[Nn]*|"" ) NGINX_SEC=false; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
}

#####    EXTENSIONS MENU    ########################################
ext_menu () {
SUB_MENU_TITLE="Extensions Menu"

menu_header

while true; do
	read -p "${Green} Would you like to install any standard Guacamole extensions (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) 
			INSTALL_EXT=true
			ext_sel_menu
			break;;
		[Nn]*|"" )
			INSTALL_EXT=false
			INSTALL_LDAP=false
			SECURE_LDAP=false
			INSTALL_TOTP=false
			INSTALL_DUO=false
			INSTALL_RADIUS=false
			INSTALL_CAS=false
			INSTALL_OPENID=false
			break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
}

#####    EXTENSIONS SELECTION MENU    ########################################
ext_sel_menu () {
# All possible options (may depend on Guac version and other configuration)
# "LDAP" "TOTP" "Duo" "Radius" "CAS" "OpenID"
# Currenlty only LDAP is woring via this script
options=("LDAP" "TOTP" "Duo" "Radius" "CAS" "OpenID")
choices=()
selections=()
INSTALL_LDAP=false
SECURE_LDAP=false
INSTALL_TOTP=false
INSTALL_DUO=false
INSTALL_RADIUS=false
INSTALL_CAS=false
INSTALL_OPENID=false

# This function is used to print the extension choices menu
ext_sub_menu() {
	echo "${Green} Select the desired extensions to install:${Yellow}"
	for i in ${!options[@]}; do 
		printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
	done
	[[ "$msg" ]] && echo "$msg"; :
}

# This function is used to select/deselect extensions from the menu
ext_sub_prompt () {
prompt="${Green} Enter a number and press ENTER to check/uncheck an option. Selections designated by a + sign. (Press ENTER while blank when done): "
while ext_sub_menu && read -rp "$prompt" num && [[ "$num" ]]; do
	[[ "$num" != *[![:digit:]]* ]] &&
	(( num > 0 && num <= ${#options[@]} )) ||
	{ msg="Invalid option: $num"; continue; }
	((num--)); msg=" ${options[num]} was ${choices[num]:+un}checked"
	[[ "${choices[num]}" ]] && unset 'choices[num]' || choices[num]="+"
done

# Ensure that at least 1 extension is selected
if [[ ${#choices[@]} == 0 ]]; then
	echo "${Red} At least one extension needs to be selected, please pick one."
	msg=""
	ext_sub_prompt
fi
}

ext_sub_prompt

# Loop final extension selections and call the specific function for each
for i in ${!options[@]}; do
	[[ "${choices[i]}" ]] && ${options[i]}_ext_menu
	[[ "${choices[i]}" ]] && selections+=(${options[i]}) # An array of the selections only used for the extensions summary menu
done

# Adds this entry to the array for use in the extensions summary menu
selections+=("Return to Standard Extension Summary")
}

#####    LDAP MENU    ########################################
LDAP_ext_menu () {
INSTALL_LDAP=true
SUB_MENU_TITLE="LDAP Extension Menu"

menu_header

while true; do
	read -p "${Green} Use LDAPS instead of LDAP (Requires having the cert from the server copied locally, default: no): ${Yellow}" SECURE_LDAP
	case $SECURE_LDAP in
		[Yy]* ) SECURE_LDAP=true; break;;
		[Nn]*|"" ) SECURE_LDAP=false; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

# Check if LDAPS was selected
if [ $SECURE_LDAP = true ]; then
	echo -n "${Green} Enter the LDAP Port (default 636): ${Yellow}"
		read LDAP_PORT
		LDAP_PORT=${LDAP_PORT:-636}

	# LDAPS Certificate placeholder values
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

	echo -n "${Green} Set the password for the CACert Java Keystore, must be 6 or more characters (default ${JKS_CACERT_PASSWD_DEF}): ${Yellow}"
		read JKS_CACERT_PASSWD
		JKS_CACERT_PASSWD=${JKS_CACERT_PASSWD:-${JKS_CACERT_PASSWD_DEF}}
else # Use LDAP not LDAPS
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

LDAP_SEARCH_FILTER_DEF="(objectClass=*)"
echo -n "${Green} Enter a custom LDAP user search filter (default \"${LDAP_SEARCH_FILTER_DEF}\"): ${Yellow}"
	read LDAP_SEARCH_FILTER
	LDAP_SEARCH_FILTER=${LDAP_SEARCH_FILTER:-${LDAP_SEARCH_FILTER_DEF}}
}

#####    TOTP MENU    ########################################
TOTP_ext_menu () {
INSTALL_TOTP=false
SUB_MENU_TITLE="TOTP Extension Menu"

menu_header

echo -e "${Red} TOTP extension not currently available via this script."
sleep 5

tput sgr0
}

#####    DUO MENU    ########################################
Duo_ext_menu () {
INSTALL_DUO=false
SUB_MENU_TITLE="DUO Extension Menu"

menu_header

echo -e "${Red} Duo extension not currently available via this script."
sleep 5

tput sgr0
}

#####    RADIUS MENU    ########################################
Radius_ext_menu () {
INSTALL_RADIUS=false
SUB_MENU_TITLE="RADIUS Extension Menu"

menu_header

echo -e "${Red} RADIUS extension not currently available via this script."
sleep 5

tput sgr0
}

#####    CAS MENU    ########################################
CAS_ext_menu () {
INSTALL_CAS=false
SUB_MENU_TITLE="CAS Extension Menu"

menu_header

echo -e "${Red} CAS extension not currently available via this script."
sleep 5

tput sgr0
}

#####    OpenID MENU    ########################################
OpenID_ext_menu () {
INSTALL_OPENID=false
SUB_MENU_TITLE="OpenID Extension Menu"

menu_header

echo -e "${Red} OpenID extension not currently available via this script."
sleep 5

tput sgr0
}

#####    CUSTOM EXTENSION MENU    ########################################
cust_ext_menu () {
SUB_MENU_TITLE="Custom Extension Menu"

menu_header

while true; do
	read -p "${Green} Would you like to install a custom Guacamole extensions from a local file (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* )
			INSTALL_CUST_EXT=true

			# Set placeholder values
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
			break;;
		[Nn]*|"" ) INSTALL_CUST_EXT=false; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
}

##########################################################
#####      SUMMARY MENUs    ##############################
##########################################################

#####      MAIN SUMMARY MENU   ###################################
sum_menu () {
SUB_MENU_TITLE="Summary Menu"

menu_header

RUN_INSTALL=false

# List categories/menus to review or change
echo -e "${Green} Select a category to review selections: ${Yellow}"
PS3="${Green} Enter the number of the category to review: ${Yellow}"
options=("Database" "Passwords" "SSL Cert Type" "Nginx" "Standard Extensions" "Custom Extension" "Accept and Run Installation" "Cancel and Start Over" "Cancel and Exit Script")
select opt in "${options[@]}"
do
	case $opt in
		"Database") sum_db; break;;
		"Passwords") sum_pw; break;;
		"SSL Cert Type") sum_ssl; break;;
		"Nginx") sum_nginx; break;;
		"Standard Extensions") sum_ext; break;;
		"Custom Extension") sum_cust_ext; break;;
		"Accept and Run Installation") RUN_INSTALL=true; break;;
		"Cancel and Start Over") ScriptLoc=$(readlink -f "$0"); exec "$ScriptLoc"; break;;
		"Cancel and Exit Script") tput sgr0; exit 1; break;;
		* ) echo "${Green} ${REPLY} is not a valid option, enter the number representing the category to review.";;
		esac
done

tput sgr0
}

#####      DATABASE SUMMARY       ###################################
sum_db () {
SUB_MENU_TITLE="Database Summary"

menu_header

echo -e "${Green} Guacamole DB name: ${Yellow}${DB_NAME}"
echo -e "${Green} Guacamole DB username: ${Yellow}${DB_USER}"
echo -e "${Green} Java KeyStore key-size: ${Yellow}${JKSTORE_KEY_SIZE}\n"

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) db_menu; break;;
		[Nn]*|"" ) sum_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
}

#####      PASSWORD SUMMARY       ###################################
sum_pw () {
SUB_MENU_TITLE="Passwords Summary"

menu_header

echo -e "${Green} MariaDB root password: ${Yellow}${MYSQL_PASSWD}"
echo -e "${Green} Guacamole DB password: ${Yellow}${DB_PASSWD}"
echo -e "${Green} Guacamole Java KeyStore password: ${Yellow}${JKS_GUAC_PASSWD}\n"

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) pw_menu; break;;
		[Nn]*|"" ) sum_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
}

#####      SSL CERTIFICATE SUMMARY       ###################################
sum_ssl () {
SUB_MENU_TITLE="SSL Certificate Summary"

menu_header

echo -e "${Green} Certficate Type: ${Yellow}${SSL_CERT_TYPE}\n"

# Check the certificate selection to display proper information for selection
case $SSL_CERT_TYPE in
	"LetsEncrypt")
		echo -e "${Green} e-mail for LetsEncrypt certificate: ${Yellow}${EMAIL_NAME}"
		echo -e "${Green} LetEncrypt key-size: ${Yellow}${LE_KEY_SIZE}"
		echo -e "${Green} Use OCSP Stapling?: ${Yellow}${OCSP_USE}\n"
		;;
	"Self-signed")
		echo -e "${Green} Self-Signed SSL key-size: ${Yellow}${SSL_KEY_SIZE}\n"
		;;
	"None")
		echo -e "${Yellow} As no certificate type was selected, an SSL certificate can be configured manually at a later time.\n"
		;;
esac

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) ssl_cert_type_menu; break;;
		[Nn]*|"" ) sum_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
}

#####      NGINX SUMMARY       ###################################
sum_nginx () {
SUB_MENU_TITLE="Nginx Summary"

menu_header

echo -e "${Green} Guacamole Server LAN IP address: ${Yellow}${GUAC_LAN_IP}"
echo -e "${Green} Guacamole Server hostname or public domain: ${Yellow}${DOMAIN_NAME}"
echo -e "${Green} URI path: ${Yellow}${GUAC_URIPATH}"
echo -e "${Green} Using only 256-bit >= ciphers?: ${Yellow}${NGINX_SEC}\n"

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) nginx_menu; break;;
		[Nn]*|"" ) sum_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
}

#####      STANDARD EXTENSION SUMMARY       ###################################
sum_ext () {
SUB_MENU_TITLE="Standard Extension Summary"

menu_header

echo -e "${Green} Install standard Guacamole extensions: ${Yellow}${INSTALL_EXT}\n"

echo -e "${Green} Do you want to: ${Yellow}"
PS3="${Green} Enter the number of the action to take: ${Yellow}"
actions=("View/change selected extensions and their settings" "Change if extensions are installed and if so which" "Return to the Summary menu")

select a in "${actions[@]}"
do
	case $a in
		"View/change selected extensions and their settings") sum_sel_ext; break;;
		"Change if extensions are installed and if so which") ext_menu; break;;
		"Return to the Summary menu") sum_menu; break;;
		* ) echo "${Green} ${REPLY} is not a valid option, enter the number representing the action to take.";;
	esac
done

tput sgr0
sum_menu
}

#####      SELECTED EXTENSIONS SUMMARY       ###################################
sum_sel_ext () {
SUB_MENU_TITLE="Summary of Selected Extensions"

menu_header

# Check if installing extensions was selected
if [ ${INSTALL_EXT} = true ]; then
	ext_selections=$(( ${#selections[@]} - 1 ))
	echo -e "${Green} Number of extensions selected: ${Yellow}${ext_selections}\n"

	# Lists only the selected extensions to review the settings of
	PS3="${Green} Select the number of the extension to view: ${Yellow}"

	select s in "${selections[@]}"
	do
		case $s in
			"LDAP") sum_LDAP; break;;
			"TOTP") sum_TOTP; break;;
			"Duo") sum_Duo; break;;
			"Radius") sum_Radius; break;;
			"CAS") sum_CAS; break;;
			"OpenID") sum_OpenID; break;;
			"Return to Standard Extension Summary") sum_ext; break;;
			* ) echo "Select a valid option.";;
			esac
		done
else # Installing extensions was set to "no"
	echo -e "${Green} Installation of extensions was declined.\n If you want to install extensions, change if extensions are installed from the Standard Extension Summary menu using option 2"
	sleep 5
fi

tpu sgr0
sum_ext
}

#####      LDAP SUMMARY       ###################################
sum_LDAP () {
SUB_MENU_TITLE="LDAP Extension Summary"	

menu_header

echo -e "${Green} Use LDAPS instead of LDAP: ${Yellow}${SECURE_LDAP}"
echo -e "${Green} LDAP(S) port: ${Yellow}${LDAP_PORT}\n"

if [ $SECURE_LDAP = true ]; then
	echo -e "${Green} LDAPS full filename and path: ${Yellow}${LDAPS_CERT_FULL}"
	echo -e "${Green} CACert Java Keystroe password: ${Yellow}${JKS_CACERT_PASSWD}\n"
fi

echo -e "${Green} LDAP Server Hostname (should be FQDN, Ex: ldaphost.domain.com): ${Yellow}${LDAP_HOSTNAME}"
echo -e "${Green} LDAP User-Base-DN (Ex: dc=domain,dc=com): ${Yellow}${LDAP_BASE_DN}"
echo -e "${Green} LDAP Search-Bind-DN (Ex: cn=user,ou=Admins,dc=doamin,dc=com): ${Yellow}${LDAP_BIND_DN}"
echo -e "${Green} LDAP Search-Bind-Password: ${Yellow}${LDAP_BIND_PW}"
echo -e "${Green} LDAP Username-Attribute: ${Yellow}${LDAP_UNAME_ATTR}"
echo -e "${Green} LDAP user search filter: ${Yellow}${LDAP_SEARCH_FILTER}\n"

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) LDAP_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      TOTP SUMMARY       ###################################
# Need to add TOTP properties
sum_TOTP () {
SUB_MENU_TITLE="TOTP Extension Summary"	

menu_header

echo -e "${Red} TOTP cannot currently be installed by this script."

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) TOTP_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      DUP SUMMARY       ###################################
# Need to add Duo properties
sum_Duo () {
SUB_MENU_TITLE="Duo Extension Summary"	

menu_header

echo -e "${Red} Duo cannot currently be installed by this script."

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) Duo_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      RADIUS SUMMARY       ###################################
# Need to add Radius properties
sum_Radius () {
SUB_MENU_TITLE="RADIUS Extension Summary"	

menu_header

echo -e "${Red} RADIUS cannot currently be installed by this script."

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) Radius_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      CAS SUMMARY       ###################################
# Need to add CAS properties
sum_CAS () {
SUB_MENU_TITLE="CAS Extension Summary"	

menu_header

echo -e "${Red} CAS cannot currently be installed by this script."

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) CAS_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      OpenID SUMMARY       ###################################
# Need to add OpenID properties
sum_OpenID () {
SUB_MENU_TITLE="OpenID Extension Summary"	

menu_header

echo -e "${Red} OpenID cannot currently be installed by this script."

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) OpenID_ext_menu; break;;
		[Nn]*|"" ) sum_sel_ext; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done
}

#####      CUSTOM EXTENSION SUMMARY       ###################################
sum_cust_ext () {
SUB_MENU_TITLE="Custom Extension Summary"

menu_header

echo -e "${Green} Install a custom Guacamole extension: ${Yellow}${INSTALL_CUST_EXT}"

if [ $INSTALL_CUST_EXT = true ]; then
	echo -e "${Green} Filename of the .jar extension file: ${Yellow}${CUST_FN}"
	echo -e "${Green} Full path of the dir containing the .jar extension file: ${Yellow}${CUST_DIR}"
	echo -e "${Green} Full file path: ${Yellow}${CUST_FULL}\n"
fi

while true; do
	read -p "${Green} Would you like to change these selections (default no)? ${Yellow}" yn
	case $yn in
		[Yy]* ) cust_ext_menu; break;;
		[Nn]*|"" ) sum_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
}

#####    CONTINUE EXECUTION   ################################
db_menu
pw_menu
ssl_cert_type_menu
nginx_menu
ext_menu
cust_ext_menu
sum_menu

# Sets file descriptor to 3 for this special echo function and spinner
exec 3>&1

#####    SPINNER      ########################################
# Shows progress as a spinning line at the end of an outputted line for the last run command
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
		echo -ne "\b\b\b${Bold}[${Green}$i${Reset}${Bold}]" >&3
		sleep .5
	done
done

echo -ne "\b\b\b${Bold}[${Green}$-done-${Reset}${Bold}]" >&3
}

# This allows echoing to log and stdout while sending all else to log by default using exec
s_echo () {
	# Use first arg to determine if echo skips a line
	case $1 in
		# No preceeding blank line 
		[Nn])
			echo -ne "\n${2}" | tee -a /dev/fd/3 ;;
		# Preceeding blank line
		[Yy]|*)
			echo -ne "\n\n${2}" | tee -a /dev/fd/3 ;;
	esac
}

#################################################################
#####    INSTALLATION    ########################################
#################################################################

# Used to force all stdout and stderr to the log file
# s_echo function will be used when echos need to be displayed and logged
exec &> "${logfile}"

#####    REPOS INSTALL      ########################################
reposinstall () {
s_echo "n" "${Bold}   ----====Installing====----"
s_echo "y" "Installing Repos..."

# Install EPEL Repo
rpm -qa | grep epel-release
RETVAL=${PIPESTATUS[1]}

if [ $RETVAL -eq 0 ]; then
	s_echo "n" "${Reset}-EPEL is installed."
else
	rpm -Uvh http://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VER}.noarch.rpm &
	s_echo "n" "${Reset}-EPEL is missing. Installing...    "; spinner
fi

# Install RPMFusion Repo
rpm -qa | grep rpmfusion
RETVAL=${PIPESTATUS[1]}

if [ $RETVAL -eq 0 ]; then
	s_echo "n" "-RPMFusion is installed."
else
	rpm -Uvh https://download1.rpmfusion.org/free/el/rpmfusion-free-release-${MAJOR_VER}.noarch.rpm &
	s_echo "n" "-RPMFusion is missing. Installing...    "; spinner
fi

# Enable repos needed if using RHEL
if [ $OS_NAME == "RHEL" ] ; then
	subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms" &
	s_echo "n" "-Enabling ${OS_NAME} optional and extras repos...    "; spinner
fi

yumupdate
}

#####    YUM UPDATES    ########################################
yumupdate () {

# Update packages
yum update -y &
s_echo "y" "${Bold}Updating ${OS_NAME}, please wait...    "; spinner

baseinstall
}

#####    INSTALL BASE PACKAGES    ########################################
baseinstall () {
s_echo "y" "${Bold}Installing Required Dependencies..."

# Install libjpeg-turbo
rpm -qa | grep libjpeg-turbo-official-${LIBJPEG_VER}
RETVAL=${PIPESTATUS[1]}; echo -e "rpm -qa | grep libjpeg-turbo-official-${LIBJPEG_VER} RC is: $RETVAL"

if [ $RETVAL -eq 0 ]; then
	s_echo "n" "${Reset}-libjpeg-turbo-official-${LIBJPEG_VER} is installed"
else
	yum localinstall -y ${LIBJPEG_URL}${LIBJPEG_TURBO}.${MACHINE_ARCH}.rpm &
	s_echo "n" "${Reset}-libjpeg-turbo-official-${LIBJPEG_VER} is not installed, installing...    "; spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum localinstall -y ${LIBJPEG_URL}${LIBJPEG_TURBO}.${MACHINE_ARCH}.rpm RC is: $RETVAL"
	ln -vfs /opt/libjpeg-turbo/include/* /usr/include/
	ln -vfs /opt/libjpeg-turbo/lib??/* /usr/lib${ARCH}/
fi

# Install ffmpeg-devel
rpm -qa | grep ffmpeg-devel
RETVAL=${PIPESTATUS[1]} ; echo -e "rpm -qa | grep ffmpeg-devel RC is: $RETVAL"
if [ $RETVAL -eq 0 ]; then
	s_echo "n" "-ffmpeg-devel is installed";
else
	yum install -y ffmpeg-devel &
	s_echo "n" "-ffmpeg-devel is not installed, installing...    "; spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum install -y ffmpeg-devel RC is: $RETVAL"
fi

# Install Required Packages
yum install -y wget dialog gcc cairo-devel libpng-devel uuid-devel freerdp-devel freerdp-plugins pango-devel libssh2-devel libtelnet-devel libvncserver-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel tomcat gnu-free-mono-fonts mariadb mariadb-server policycoreutils-python setroubleshoot &
s_echo "n" "-Installing other required packages...    "; spinner
RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC is: $RETVAL"

# Additional packages required by git
if [ $GUAC_SOURCE == "Git" ]; then
	yum install -y git libtool libwebsockets java-1.8.0-openjdk-devel &
	s_echo "n" "-Installing packages required for git...    "; spinner
	RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC for git is: $RETVAL"

	#Install Maven
	{
		cd /opt
		wget ${MAVEN_URL}${MAVEN_BIN}
		tar -xvzf ${MAVEN_BIN}
		ln -s ${MAVEN_FN} maven
		export PATH=/opt/maven/bin:${PATH}
		rm -rf /opt/${MAVEN_BIN}
		cd ~
	} &
	s_echo "n" "-Installing Apache Maven for git...    "; spinner
fi

createdirs
}

#####    CREATE DIRS    ########################################
createdirs () {
	{
		rm -fr ${INSTALL_DIR}
		mkdir -v /etc/guacamole
		mkdir -vp ${INSTALL_DIR}{client,selinux}
		cd ${INSTALL_DIR}
		mkdir -vp ${LIB_DIR}{extensions,lib}
		mkdir -v /usr/share/tomcat/.guacamole/
	} &
	s_echo "y" "${Bold}Creating Required Directories...    "; spinner

downloadguac
}

#####    DOWNLOAD GUAC    ########################################
downloadguac () {
s_echo "y" "Downloading Guacamole Packages..."

if [ $GUAC_SOURCE == "Git" ]; then
	git clone ${GUAC_URL}${GUAC_SERVER} &
	s_echo "n" "-Cloning Guacamole Server package from git...    "; spinner
	git clone ${GUAC_URL}${GUAC_CLIENT} &
	s_echo "n" "-Cloning Guacamole Client package from git...    "; spinner
	downloadmysqlconn
else # Stable release
	wget "${GUAC_URL}source/${GUAC_SERVER}.tar.gz" -O ${GUAC_SERVER}.tar.gz &
	s_echo "n" "-Downloading Guacamole Server package for installation...    "; spinner
	wget "${GUAC_URL}binary/${GUAC_CLIENT}.war" -O ${INSTALL_DIR}client/guacamole.war &
	s_echo "n" "-Downloading Guacamole Client package for installation...    "; spinner
	wget "${GUAC_URL}binary/${GUAC_JDBC}.tar.gz" -O ${GUAC_JDBC}.tar.gz &
	s_echo "n" "-Downloading Guacamole JDBC Extension package for installation...    "; spinner
	downloadmysqlconn
	
	# Decompress Guacamole Packages
	s_echo "y" "${Bold}Decompressing Guacamole Packages..."

	{
		tar xzvf ${GUAC_SERVER}.tar.gz
		rm -f ${GUAC_SERVER}.tar.gz
		mv -v ${GUAC_SERVER} server
	} &
	s_echo "n" "${Reset}-Decompressing Guacamole Server source...    "; spinner

	{
		tar xzvf ${GUAC_JDBC}.tar.gz
		rm -f ${GUAC_JDBC}.tar.gz
		mv -v ${GUAC_JDBC} extension
		mv -v extension/mysql/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar ${LIB_DIR}extensions/ || exit 1
	} &
	s_echo "n" "-Decompressing Guacamole JDBC extension...    "; spinner
fi
	
	# MySQL Connector
	downloadmysqlconn () {
		wget ${MYSQL_CON_URL}${MYSQL_CON}.tar.gz
		s_echo "n" "-Downloading MySQL Connector package for installation...    "; spinner
	}

{
	tar xzvf ${MYSQL_CON}.tar.gz
	rm -f ${MYSQL_CON}.tar.gz
	mv -v ${MYSQL_CON}/${MYSQL_CON}.jar ${LIB_DIR}lib/ || exit 1
} &
s_echo "n" "$-Decompressing MySQL Connector...    "; spinner

installguacserver
}

#####    INSTALL GUAC SERVER    ########################################
installguacserver () {
s_echo "y" "${Bold}Install Guacamole Server..."

if [ $GUAC_SOURCE == "Git" ]; then
	cd guacamole-server/
	autoreconf -fi &
	s_echo "n" "${Reset}-Guacamole Server compile prep...    "; spinner
else # Stable release
	cd server
fi

# Compile Guacamole Server
./configure --with-systemd-dir=/etc/systemd/system &
s_echo "n" "${Reset}-Compiling Guacamole Server Stage 1 of 4...    "; spinner
make &
s_echo "n" "-Compiling Guacamole Server Stage 2 of 4...    "; spinner
sleep 1 && make install &
s_echo "n" "-Compiling Guacamole Server Stage 3 of 4...    "; spinner
sleep 1 && ldconfig &
s_echo "n" "-Compiling Guacamole Server Stage 4 of 4...    "; spinner
cd ..

installguacclient
}

#####    INSTALL GUAC CLIENT    ########################################
installguacclient () {
s_echo "y" "${Bold}Install Guacamole Client..."

if [ $GUAC_SOURCE == "Git" ]; then
	{
		cd guacamole-client/
		mvn package
	} &
	s_echo "n" "${Reset}-Compiling Guacamole Client...    "; spinner

	{
		mv -v guacamole/target/guacamole-${GUAC_VER}.war ${LIB_DIR}guacamole.war
		cd ..
	} &
	s_echo "n" "-Moving Guacamole Client...    "; spinner
else # Stable release
	mv -v client/guacamole.war ${LIB_DIR}guacamole.war &
	s_echo "n" "${Reset}-Moving Guacamole Client...    "; spinner
fi

finishguac
}

#####    FINALIZE GUAC    ########################################
finishguac () {
s_echo "y" "${Bold}Setup Guacamole..."

# Generate Guacamole Configuration File
echo "# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port:     ${GUAC_PORT}
# MySQL properties
mysql-hostname: localhost
mysql-port: ${MYSQL_PORT}
mysql-database: ${DB_NAME}
mysql-username: ${DB_USER}
mysql-password: ${DB_PASSWD}
mysql-default-max-connections-per-user: 0
mysql-default-max-group-connections-per-user: 0" > /etc/guacamole/${GUAC_CONF} &
s_echo "n" "${Reset}-Generating Guacamole configuration file...    "; spinner

# Create Required Symlinks for Guacamole
{
	ln -vfs ${LIB_DIR}guacamole.war /var/lib/tomcat/webapps || exit 1
	ln -vfs /etc/guacamole/${GUAC_CONF} /usr/share/tomcat/.guacamole/ || exit 1
	ln -vfs ${LIB_DIR}lib/ /usr/share/tomcat/.guacamole/ || exit 1
	ln -vfs ${LIB_DIR}extensions/ /usr/share/tomcat/.guacamole/ || exit 1
	ln -vfs /usr/local/lib/freerdp/guac* /usr/lib${ARCH}/freerdp || exit 1
} &
s_echo "n" "-Making required symlinks...    "; spinner

# Copy JDBC if using git
if [ $GUAC_SOURCE == "Git" ]; then
	# Get JDBC from compiled client
	find ./guacamole-client/extensions -name "guacamole-auth-jdbc-mysql-${GUAC_VER}.jar" -exec mv -v {} ${LIB_DIR}extensions/ \; &
	s_echo "n" "-Moving Guacamole JDBC extension to extensions dir...    "; spinner
#else # Stable release
	# Copy JDBC from download
#	mv -v extension/mysql/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar ${LIB_DIR}extensions/ || exit 1
fi

# Copy MySQL Connector
# s_echo "y" "${Bold}Copying MySQL Connector to Lib Dir..."
# mv -v ${MYSQL_CON}/${MYSQL_CON}.jar ${LIB_DIR}lib/ || exit 1

appconfigs
}

#####    DATABASE/TOMCAT/JKS SETUP    ########################################
appconfigs () {
s_echo "y" "${Bold}Configure MariaDB..."

# Enable/Start MariaDB/MySQL Service
{
	systemctl enable mariadb.service
	systemctl restart mariadb.service
} &
s_echo "n" "${Reset}-Enable & start MariaDB service...    "; spinner

# Set MariaDB/MySQL Root Password
mysqladmin -u root password ${MYSQL_PASSWD} &
s_echo "n" "-Setting root password for MariaDB...    "; spinner

# Run MariaDB/MySQL Secure Install
{
	mysql_secure_installation <<EOF
${MYSQL_PASSWD}
n
y
y
y
y
EOF
} &
s_echo "n" "-Harden MariaDB...    "; spinner

# Create Database and user
{
	mysql -u root -p${MYSQL_PASSWD} -e "CREATE DATABASE ${DB_NAME};" || exit 1
	mysql -u root -p${MYSQL_PASSWD} -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWD}';" || exit 1
	mysql -u root -p${MYSQL_PASSWD} -e "FLUSH PRIVILEGES;" || exit 1
} &
s_echo "n" "-Creating database & user for Guacamole...    "; spinner

# Create Guacamole Table
{
	if [ $GUAC_SOURCE == "Git" ]; then
		cat guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/schema/*.sql | mysql -u root -p${MYSQL_PASSWD} -D ${DB_NAME}
	else # Stable release
		cat extension/mysql/schema/*.sql | mysql -u root -p${MYSQL_PASSWD} -D ${DB_NAME}
	fi
} &
s_echo "n" "-Creating Guacamole Tables...    "; spinner

# Setup Tomcat
s_echo "y" "${Bold}Setup Tomcat Server..."

{
	sed -i '72i URIEncoding="UTF-8"' /etc/tomcat/server.xml
	sed -i '92i <Connector port="8443" protocol="HTTP/1.1" SSLEnabled="true" \
							maxThreads="150" scheme="https" secure="true" \
							clientAuth="false" sslProtocol="TLS" \
							keystoreFile="/var/lib/tomcat/webapps/.keystore" \
							keystorePass="JKS_GUAC_PASSWD" \
							URIEncoding="UTF-8" />' /etc/tomcat/server.xml
	sed -i "s/JKS_GUAC_PASSWD/${JKS_GUAC_PASSWD}/g" /etc/tomcat/server.xml
} &
s_echo "n" "-${Reset}-Base Tomcat configure...    "; spinner

{
# Tomcat RemoteIpValve (to pass remote host IP's from proxy to tomcat. Allows Guacamole to log remote host IPs)
	sed -i '/<\/Host>/i\<Valve className="org.apache.catalina.valves.RemoteIpValve" \
							internalProxies="GUAC_SERVER_IP" \
							remoteIpHeader="x-forwarded-for" \
							remoteIpProxiesHeader="x-forwarded-by" \
							protocolHeader="x-forwarded-proto" />' /etc/tomcat/server.xml

	sed -i "s/GUAC_SERVER_IP/${GUAC_LAN_IP}/g" /etc/tomcat/server.xml
} &
s_echo "n" "-Set RemoteIpValve in Tomcat configuration...    "; spinner

{
# Add ErrorReportingValve to prevent displaying tomcat info on error pages
	sed -i '/<\/Host>/i\<Valve className="org.apache.catalina.valves.ErrorReportValve" \
							showReport="false" \
							showServerInfo="false"/>' /etc/tomcat/server.xml
} &
s_echo "n" "-Set ErrorReportingVavle in Tomcat configuration...    "; spinner

# Java KeyStore Setup
keytool -genkey -alias Guacamole -keyalg RSA -keysize ${JKSTORE_KEY_SIZE} -keystore /var/lib/tomcat/webapps/.keystore -storepass ${JKS_GUAC_PASSWD} -keypass ${JKS_GUAC_PASSWD} -noprompt -dname "CN='', OU='', O='', L='', S='', C=''" &
s_echo "y" "${Bold}Configuring the Java KeyStore...    "; spinner

# Enable/Start Tomcat and Guacamole Services
{
	systemctl enable tomcat
	systemctl restart tomcat
	systemctl enable guacd
	systemctl restart guacd
} &
s_echo "y" "Enable & Start Tomcat and Guacamole Services...    "; spinner

nginxinstall
}

#####    NGINX INSTALL    ########################################
nginxinstall () {
s_echo "y" "Install Nginx..."

# Install Nginx Repo
echo "[nginx]
name=nginx repo
baseurl=${NGINX_URL}
gpgcheck=0
enabled=1" > /etc/yum.repos.d/nginx.repo &
s_echo "n" "${Reset}-Installing Nginx repository...    "; spinner

# Install Nginx
yum install -y nginx &
s_echo "n" "-Installing Nginx...    "; spinner
RETVAL=${PIPESTATUS[0]} ; echo -e "yum install RC is: $RETVAL"

# Generate Nginx Conf's
s_echo "y" "${Bold}Nginx Configurations..."

# Backup Nginx Configuration
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.ori.bkp
s_echo "n" "${Reset}-Making Nginx config backup...    "; spinner

# HTTP Nginx Conf
echo "server {
	listen 80;
	listen [::]:80;
	server_name ${DOMAIN_NAME};
	return 301 https://\$host\$request_uri;

	location ${GUAC_URIPATH} {
	proxy_pass http://${GUAC_LAN_IP}:8080/guacamole/;
	proxy_buffering off;
	proxy_http_version 1.1;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header Upgrade \$http_upgrade;
	proxy_set_header Connection \$http_connection;
	proxy_cookie_path /guacamole/ ${GUAC_URIPATH};
	access_log off;
	}
}" > /etc/nginx/conf.d/guacamole.conf &
s_echo "n" "${Reset}-Generate Nginx guacamole.config...    "; spinner

{
	# HTTPS/SSL Nginx Conf
	echo "server {
		listen 443 ssl http2 default_server;
		listen [::]:443 ssl http2 default_server;
		server_name ${DOMAIN_NAME};
		server_tokens off;
		#ssl_certificate guacamole.crt;
		#ssl_certificate_key guacamole.key; " > /etc/nginx/conf.d/guacamole_ssl.conf

	# If OCSP Stapling was selected
	if [ $OCSP_USE = true ]; then
		echo "	#ssl_trusted_certificate guacamole.pem;
		ssl_stapling on;
		ssl_stapling_verify on;" >> /etc/nginx/conf.d/guacamole_ssl.conf
	fi

	# If using >= 256-bit ciphers
	if [ $NGINX_SEC = true ]; then
		echo "	ssl_ciphers 'TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384';" >> /etc/nginx/conf.d/guacamole_ssl.conf
	else
		echo "	ssl_ciphers 'TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';" >> /etc/nginx/conf.d/guacamole_ssl.conf
	fi

	# Rest of HTTPS/SSL Nginx Conf
	echo "	ssl_protocols TLSv1.3 TLSv1.2;
		ssl_ecdh_curve secp521r1:secp384r1:prime256v1;
		ssl_prefer_server_ciphers on;
		ssl_session_cache shared:SSL:10m;
		ssl_session_timeout 1d;
		ssl_session_tickets off;
		add_header Referrer-Policy \"no-referrer-when-downgrade\" always;
		add_header Strict-Transport-Security \"max-age=15768000; includeSubDomains\" always;
		add_header X-Frame-Options DENY;
		add_header X-Content-Type-Options nosniff;
		add_header X-XSS-Protection \"1; mode=block\";

		location ${GUAC_URIPATH} {
		proxy_pass http://${GUAC_LAN_IP}:8080/guacamole/;
		proxy_buffering off;
		proxy_http_version 1.1;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$http_connection;
		proxy_cookie_path /guacamole/ ${GUAC_URIPATH};
		access_log /var/log/nginx/guac_access.log;
		error_log /var/log/nginx/guac_error.log;
		}
	}" >> /etc/nginx/conf.d/guacamole_ssl.conf
} &
s_echo "n" "-Generate Nginx guacamole_ssl.config...    "; spinner

# Enable/Start Nginx Service
{
	systemctl enable nginx || exit 1
	systemctl restart nginx || exit 1
} &
s_echo "n" "-Enable & Start Nginx Service...    "; spinner

# s_echo "y" "${Bold}If you need to understand the Nginx configurations please go to:\n ${Green} http://nginx.org/en/docs/ \n${Reset}${Bold}If you need to replace the certificate file please read first:\n ${Green} http://nginx.org/en/docs/http/configuring_https_servers.html ${Reset}"

# Call each Guac extension function for those selected
if [ $INSTALL_LDAP = true ]; then ldapsetup; fi
if [ $INSTALL_TOTP = true ]; then totpsetup; fi
if [ $INSTALL_DUO = true ]; then duosetup; fi
if [ $INSTALL_RADIUS = true ]; then radiussetup; fi
if [ $INSTALL_CAS = true ]; then cassetup; fi
if [ $INSTALL_OPENID = true ]; then openidsetup; fi
if [ $INSTALL_CUST_EXT = true ]; then custsetup; fi

selinuxsettings
}

#####    LDAP SETUP    ########################################
ldapsetup () {
s_echo "y" "${Bold}Setup the LDAP Extension..."

# Append LDAP configuration lines to guacamole.properties
echo "
# LDAP properties
ldap-hostname: ${LDAP_HOSTNAME}
ldap-port: ${LDAP_PORT}" >> /etc/guacamole/${GUAC_CONF} &
s_echo "n" "${Reset}-Updating guacamole.properties file for LDAP...    "; spinner

# LDAPS specific properties
if [ $SECURE_LDAP = true ]; then
	{
		KS_PATH=$(find "/usr/lib/jvm/" -name "cacerts")
		keytool -storepasswd -new ${JKS_CACERT_PASSWD} -keystore ${KS_PATH} -storepass "changeit" 
		keytool -importcert -alias "ldaps" -keystore ${KS_PATH} -storepass ${JKS_CACERT_PASSWD} -file ${LDAPS_CERT_FULL} -noprompt

		echo "ldap-encryption-method: ssl" >> /etc/guacamole/${GUAC_CONF}
	} &
	s_echo "n" "-Updating guacamole.properties file for LDAPS...    "; spinner
fi

echo "ldap-user-base-dn: ${LDAP_BASE_DN}
ldap-search-bind-dn: ${LDAP_BIND_DN}
ldap-search-bind-password: ${LDAP_BIND_PW}
ldap-username-attribute: ${LDAP_UNAME_ATTR}
ldap-user-search-filter: ${LDAP_SEARCH_FILTER}" >> /etc/guacamole/${GUAC_CONF} &
s_echo "n" "-Finishing updates to the guacamole.properties file for LDAPS...    "; spinner

if [ $GUAC_SOURCE == "Git" ]; then
	# Copy LDAP Extension to Extensions Directory
	find ./guacamole-client/extensions -name "${GUAC_LDAP}.jar" -exec mv -v {} ${LIB_DIR}extensions/ \; &
	s_echo "n" "-Moving Guacamole LDAP extension to extensions dir...    "; spinner
else # Stable release
	# Download LDAP Extension
	wget "${GUAC_URL}binary/${GUAC_LDAP}.tar.gz" -O ${GUAC_LDAP}.tar.gz &
	s_echo "n" "-Downloading LDAP extension...    "; spinner

	# Decompress LDAP Extension
	{
		tar xzvf ${GUAC_LDAP}.tar.gz 
		rm -f ${GUAC_LDAP}.tar.gz
		mv ${GUAC_LDAP} extension
	} &
	s_echo "n" "-Decompressing Guacamole LDAP Extension...    "; spinner

	# Copy LDAP Extension to Extensions Directory
	mv -v extension/${GUAC_LDAP}/${GUAC_LDAP}.jar ${LIB_DIR}extensions/ & || exit 1
	s_echo "n" "-Moving Guacamole LDAP extension to extensions dir...    "; spinner
fi
}

#####    TOTP SETUP    ########################################
totpsetup () {
	# Placehold until extension is added
	echo "totpsetup"
}

#####    DUO SETUP    ########################################
duosetup () {
	# Placehold until extension is added
	echo "duosetup"
}

#####    RADIUS SETUP    ########################################
radiussetup () {
	# Placehold until extension is added
	echo "radiussetup"
}

#####    CAS SETUP    ########################################
cassetup () {
	# Placehold until extension is added
	echo "cassetup"
}

#####    OpenID SETUP    ########################################
openidsetup () {
	# Placehold until extension is added
	echo "openidsetup"
}

#####    CUSTOM EXTENSION SETUP    ########################################
custsetup () {
# Copy Custom Extension to Extensions Directory
mv -v ${CUST_FULL} ${LIB_DIR}extensions/ & || exit 1
s_echo "y" "${Bold}Copying Custom Guacamole Extension to Extensions Dir...    "; spinner
}

#####    SELINUX SETTINGS    ########################################
selinuxsettings () {
	{
		# Set Booleans
		setsebool -P httpd_can_network_connect 1
		setsebool -P httpd_can_network_relay 1
		setsebool -P tomcat_can_network_connect_db 1

		# Guacamole Client Context
		semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}guacamole.war"
		restorecon -v "${LIB_DIR}guacamole.war"

		# Guacamole JDBC Extension Context
		semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar"
		restorecon -v "${LIB_DIR}extensions/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar"

		# MySQL Connector Extension Context
		semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}lib/${MYSQL_CON}.jar"
		restorecon -v "${LIB_DIR}lib/${MYSQL_CON}.jar"

		# Guacamole LDAP Extension Context (If selected)
		if [ $INSTALL_LDAP = true ]; then
			semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole TOTP Extension Context (If selected)
		if [ $INSTALL_TOTP = true ]; then
			# Placehold until extension is added
			echo "totp true"
			#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole Duo Extension Context (If selected)
		if [ $INSTALL_DUO = true ]; then
			# Placehold until extension is added
			echo "duo true"
			#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole RADIUS Extension Context (If selected)
		if [ $INSTALL_RADIUS = true ]; then
			# Placehold until extension is added
			echo "radius true"
			#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole CAS Extension Context (If selected)
		if [ $INSTALL_CAS = true ]; then
			# Placehold until extension is added
			echo "cas true"
			#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole OpenID Extension Context (If selected)
		if [ $INSTALL_OPENID = true ]; then
			# Placehold until extension is added
			echo "openid true"
			#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
			#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar"
		fi

		# Guacamole Custom Extension Context (If selected)
		if [ $INSTALL_CUST_EXT = true ]; then
			semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${CUST_FN}"
			restorecon -v "${LIB_DIR}extensions/${CUST_FN}"
		fi
	} &

s_echo "y" "${Bold}Setting SELinux Context...    "; spinner

sestatus

firewallsettings
}

#####    FIREWALL SETTINGS    ########################################
firewallsettings () {
s_echo "y" "${Bold}Firewall Configuration..."

echo -e "Take Firewall RC...\n"
echo -e "rpm -qa | grep firewalld"
rpm -qa | grep firewalld
RETVALqaf=$?
echo -e "\nservice firewalld status"
systemctl status firewalld
RETVALsf=$?

{
if [ $RETVALqaf -eq 0 ]; then
	systemctl enable firewalld
	systemctl start firewalld
fi
} &
s_echo "n" "${Reset}-firewalld is installed and started on the system...    "; spinner

cp /etc/firewalld/zones/public.xml $fwbkpfile &
s_echo "n" "-Backing up firewall config: /etc/firewalld/zones/public.xml to: $fwbkpfile    "; spinner

# Open HTTP and HTTPS ports
{
	echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=http"
	firewall-cmd --permanent --zone=public --add-service=http
	echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=https"
	firewall-cmd --permanent --zone=public --add-service=https
} &
s_echo "n" "-Opening HTTP and HTTPS service ports...    "; spinner

# Open 8080 and 8443 ports. Need to review if this is required or not
{
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8080/tcp"
firewall-cmd --permanent --zone=public --add-port=8080/tcp
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8443/tcp"
firewall-cmd --permanent --zone=public --add-port=8443/tcp
} &
s_echo "n" "-Opening ports 8080 and 8443 on TCP...    "; spinner

echo -e "Reload firewall...\nfirewall-cmd --reload\n"
firewall-cmd --reload
s_echo "n" "-Reloading firewall...    "; spinner

sslcerts
}

#####    SSL CERTIFICATE        ########################################
sslcerts () {
s_echo "y" "${Bold}SSL Certificate Configuration..."

if [ $SSL_CERT_TYPE != "None" ]; then
	# Lets Encrypt Setup (If selected)
	if [ $SSL_CERT_TYPE = "LetsEncrypt" ]; then
		# Install certbot from repo
		yum install -y certbot python2-certbot-nginx &
		s_echo "n" "${Reset}-Downloading certboot tool...    "; spinner
		
		{
		if [ $OCSP_USE = true ]; then
			certbot certonly --nginx --must-staple -n --agree-tos --rsa-key-size ${LE_KEY_SIZE} -m "${EMAIL_NAME}" -d "${DOMAIN_NAME}"
		else # Generate without OCSP --must-staple
			certbot certonly --nginx -n --agree-tos --rsa-key-size ${LE_KEY_SIZE} -m "${EMAIL_NAME}" -d "${DOMAIN_NAME}"
		fi
		} &
		s_echo "n" "-Generating a ${SSL_CERT_TYPE} SSL Certificate...    "; spinner
		
		{
			# Symlink Lets Encrypt certs so renewal does not break Nginx
			ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" /etc/nginx/guacamole.crt || true
			ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem" /etc/nginx/guacamole.key || true
			ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/chain.pem" /etc/nginx/guacamole.pem || true
		} &
		s_echo "n" "-Creating symlinks to ${SSL_CERT_TYPE} SSL certificates...    "; spinner

		{
		#Setup automatic renewal
		systemctl enable certbot-renew.service
		systemctl enable certbot-renew.timer
		systemctl list-timers --all | grep certbot
		} &
		s_echo "n" "-Setup automatic ${SSL_CERT_TYPE} SSL certificate renewals...    "; spinner

	else # Use a Self-Signed Cert
		openssl req -x509 -sha512 -nodes -days 365 -newkey rsa:${SSL_KEY_SIZE} -keyout /etc/nginx/guacamole.key -out /etc/nginx/guacamole.crt -subj "/C=''/ST=''/L=''/O=''/OU=''/CN=''" &
		s_echo "n" "${Reset}-Generating ${SSL_CERT_TYPE} SSL Certificate...    "; spinner
	fi

	# Uncomment cert lines from Nginx guacamole_ssl.conf
	sed -i 's/#\(.*ssl_.*certificate.*\)/\1/' /etc/nginx/conf.d/guacamole_ssl.conf &
	s_echo "n" "${Reset}-Enabling SSL certificate in guacamole_ssl.conf...    "; spinner

	HTTPS_ENABLED=true
else # Is set to None
	s_echo "n" "${Reset}-No SSL Cert selected..."
	
	# Cannot force/use HTTPS without a cert, comment out redirect
	sed -i '/\(return 301 https\)/s/^/#/' /etc/nginx/conf.d/guacamole.conf &
	s_echo "n" "${Reset}-Update guacamole.conf to allow HTTP connections...    "; spinner

	HTTPS_ENABLED=false
fi

showmessages
}

#####    COMPLETION MESSAGES    ########################################
showmessages () {
s_echo "y" "${Bold}Services..."

{
# Restart all services and log status
systemctl restart tomcat || exit 1
systemctl status tomcat
systemctl restart guacd || exit 1
systemctl status guacd
systemctl restart mariadb || exit 1
systemctl status mariadb
systemctl restart nginx || exit 1
systemctl status nginx
} &
s_echo "n" "${Reset}-Restarting all services...    "; spinner

# s_echo "y" "${Bold}Finished Successfully"
s_echo "y" "${Bold}Log Files..."
s_echo "n" "${Reset}-Log file: ${logfile}"
s_echo "n" "-firewall backup file: ${fwbkpfile}"

# Determine Guac server URL for web GUI
if [ ${DOMAIN_NAME} = "localhost" ]; then
	GUAC_URL=${GUAC_LAN_IP}${GUAC_URIPATH}
else # Not localhost
	GUAC_URL=${DOMAIN_NAME}${GUAC_URIPATH}
fi

# Determine if HTTPS is used or not
if [ ${HTTPS_ENABLED} = true ]; then
	HTTPS_MSG=" or https://${GUAC_URL}"
else # HTTPS not used
	HTTPS_MSG=". Without a cert, HTTPS is not available."
fi

s_echo "y" "${Bold}To manage Guacamole go to http://${GUAC_URL}${HTTPS_MSG}"
s_echo "n" "${Reset}-The default username and password are: ${Red}guacadmin"

if [ $INSTALL_LDAP = false ]; then
	s_echo "y" "${Bold}Its highly recommended to create an admin account in Guacamole and delete/disable the default asap!${Reset}"
else
	s_echo "y" "${Bold}You should assign at least one AD/LDAP user to have full admin, see the directions on how to at:${Reset}"
	s_echo "n" "${Green}https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/LDAP-or-LDAPS-Authentication#important-manual-steps"
	s_echo "y" "${Bold}${Red}Afterwards, it is highly recommended to delete/disable the default admin account and create a uniquely named local admin account asap!${Reset}"
fi

if [ $SECURE_LDAP = true ]; then
	s_echo "y" "${Red}Its highly recommended to remove the LDAPS certificate file ${LDAPS_CERT_FULL} as its been imported into JKS${Reset}"
fi
s_echo "y" "${Green}While not typically required, you should consider a reboot after verifying installation${Reset}"
s_echo "y" "${Bold}Contact ${Reset}${ADM_POC}${Bold} with any questions or concerns regarding this script\n"

# Log cleanup to remove escape sequences caused by tput for formatting text
sed -i 's/\x1b\[[0-9;]*m\|\x1b[(]B\x1b\[m//g' ${logfile}

tput sgr0 >&3
exit 1
}

#####    INSTALL EXECUTION   ################################
if [ ${RUN_INSTALL} = true ]; then
	tput sgr0 >&3
	clear >&3
	reposinstall
fi
