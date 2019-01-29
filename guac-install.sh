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
##### CHECK FOR SUDO or ROOT ################################## 
if ! [ $(id -u) = 0 ]; then echo "This script must be run as sudo or root, try again..."; exit 1 ; fi

##########################################################
#####      VARIABLEs   ###################################
##########################################################

#####    UNIVERSAL VARS    ###################################
# USER CONFIGURABLE        #
# Generic
SCRIPT_BUILD="2019_1_29" # Scripts Date for last modified as "yyyy_mm_dd"
ADM_POC="Local Admin, admin@admin.com"  # Point of contact for the Guac server admin

# Versions
GUAC_STBL_VER="1.0.0"
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

# SSL Certificate
SSL_CERT_TYPE="Self-signed"

# Nginx
NGINX_SEC="High"

# Default Credentials
MYSQL_PASSWD_DEF="guacamole" # Default MySQL/MariaDB root password
DB_NAME_DEF="guac_db" # Defualt database name
DB_USER_DEF="guac_adm" # Defualt database user name
DB_PASSWD_DEF="guacamole" # Defualt database password
JKS_GUAC_PASSWD_DEF="guacamole" # Default Java Keystore password
JKS_CACERT_PASSWD_DEF="guacamole" # Default CACert Java Keystore password, used with LDAPS

# Misc
GUAC_URIPATH_DEF="/"
DOMAIN_NAME_DEF="localhost"

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

##### END UNIVERSAL VARS   ###################################

#####    INITIALIZE COMMON VARS    ###################################
# ONLY CHANGE IF NOT WORKING #
init_vars () {
GUAC_GIT_VER=`curl -s https://raw.githubusercontent.com/apache/guacamole-server/master/configure.ac | grep 'AC_INIT([guacamole-server]*' | awk -F'[][]' -v n=2 '{ print $(2*n) }'`
PWD=`pwd`

# Determine if OS is RHEL or not (otherwise assume CentOS)
if rpm -q subscription-manager 2>&1 > /dev/null; then IS_RHEL=true; else IS_RHEL=false; fi

MAJOR_VER=`cat /etc/redhat-release | grep -oP "[0-9]+" | head -1` # Return 5, 6 or 7 when OS is 5.x, 6.x or 7.x

if [ $IS_RHEL = true ]; then OS_NAME="RHEL"; else OS_NAME="CentOS"; fi

OS_NAME_L="$(echo $OS_NAME | tr '[:upper:]' '[:lower:]')" # Set lower case rhel or centos for use in some URLs

#Set arch used in some paths
MACHINE_ARCH=`uname -m`
if [ $MACHINE_ARCH="x86_64" ]; then ARCH="64"; elif [ $MACHINE_ARCH="i686" ]; then MACHINE_ARCH="i386"; else ARCH=""; fi

NGINX_URL=https://nginx.org/packages/$OS_NAME_L/$MAJOR_VER/$MACHINE_ARCH/ # Set nginx url for RHEL or CentOS

# Server LAN IP
GUAC_SERVER_IP=$(hostname -I | tr -d " ")
}

#####      SOURCE VARIABLES       ###################################
src_vars () {
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

GUAC_JDBC="guacamole-auth-jdbc-${GUAC_VER}"
GUAC_LDAP="guacamole-auth-ldap-${GUAC_VER}"

INSTALL_DIR="/usr/local/src/guacamole/${GUAC_VER}/"
FILENAME="${PWD}/guacamole-${GUAC_VER}_"$(date +"%d-%y-%b")""
logfile="${FILENAME}.log"
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

#####      MENU HEADERS       ###################################
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
echo -n "${Green} Enter the Guacamole Java KeyStore password (at least 6 characters): ${Yellow}"
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
			sleep 1 | echo -e "\n\n${Red} No SSL certificate selected. This can be configured manually at a later time."
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
		[Yy]|""* ) OCSP_USE=true; break;;
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

# This function is used to select/deselct extensions from the menu
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

	echo -n "${Green} Set the password for the CACert Java Keystore (default ${JKS_CACERT_PASSWD_DEF}): ${Yellow}"
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
			# Set Defaults
			CUST_FN="myextension.jar"
			CUST_FULL="xNULLx"
			INSTALL_CUST_EXT=true

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
		"Accept and Run Installation") reposinstall; break;;
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
# Provides options to review selected extensions or change if extensions are installed and if so which ones
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
	sleep 1 | echo -e "${Green} Installation of extensions was declined.\n If you want to install extensions, change if extensions are installed from the Standard Extension Summary menu using option 2"
	sleep 5
fi

tpu sgr0
sum_ext
}

#####      LDAP SUMMARY       ###################################
# Need to add LDAP properties
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
		[Nn]*|"" ) sum_sel_menu; break;;
		* ) echo "${Green} Please enter yes or no. ${Yellow}";;
	esac
done

tput sgr0
sum_menu
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

#################################################################
#####    INSTALLATION    ########################################
#################################################################

#####    REPOS INSTALL      ########################################
reposinstall () {
clear
tput sgr0
echo -e "${Bold}   ----====Installing====----" && tput sgr0

# Install EPEL Repo
sleep 1 | echo -e "\n${Bold}Searching for EPEL Repository..."; echo -e "\nSearching for EPEL Repository..." >> $logfile  2>&1
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
else # Stable release
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
else # Stable release
	cd server

	# Compile Guacamole Server
	./configure --with-systemd-dir=/etc/systemd/system >> $logfile 2>&1 &
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
else # Stable release
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
							keystorePass="JKS_GUAC_PASSWD" \
							URIEncoding="UTF-8" />' /etc/tomcat/server.xml
sed -i "s/JKS_GUAC_PASSWD/${JKS_GUAC_PASSWD}/g" /etc/tomcat/server.xml

# Tomcat RemoteIpValve (to pass remote host IP's from proxy to tomcat. Allows Guacamole to log remote host IPs)
sed -i '/<\/Host>/i\<Valve className="org.apache.catalina.valves.RemoteIpValve" \
							internalProxies="GUAC_SERVER_IP" \
							remoteIpHeader="x-forwarded-for" \
							remoteIpProxiesHeader="x-forwarded-by" \
							protocolHeader="x-forwarded-proto" />' /etc/tomcat/server.xml

sed -i "s/GUAC_SERVER_IP/${GUAC_SERVER_IP}/g" /etc/tomcat/server.xml

# Add ErrorReportingValve to prevent displaying tomcat info on error pages
sed -i '/<\/Host>/i\<Valve className="org.apache.catalina.valves.ErrorReportValve" \
							showReport="false" \
							showServerInfo="false"/>' /etc/tomcat/server.xml

# Java KeyStore Setup
sleep 1 | echo -e "\n${Bold}Please complete the Wizard for the Java KeyStore${Reset}" | pv -qL 25; echo -e "\nPlease complete the Wizard for the Java KeyStore" >> $logfile  2>&1

keytool -genkey -alias Guacamole -keyalg RSA -keysize ${JKSTORE_KEY_SIZE} -keystore /var/lib/tomcat/webapps/.keystore -storepass ${JKS_GUAC_PASSWD} -keypass ${JKS_GUAC_PASSWD} ${noprompt} | tee -a $logfile

# Enable/Start Tomcat and Guacamole Services
sleep 1 | echo -e "\n${Bold}Enable & Start Tomcat and Guacamole Service..." | pv -qL 25; echo -e "\nEnable & Start Tomcat and Guacamole Service..." >> $logfile  2>&1
systemctl enable tomcat >> $logfile  2>&1
systemctl start tomcat >> $logfile  2>&1
systemctl enable guacd >> $logfile  2>&1
systemctl start guacd >> $logfile  2>&1

nginxinstall
}

#####    NGINX INSTALL    ########################################
# Needs attention for the 3 desired levels of security
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
sleep 1 | echo -e "${Reset}-Generating Nginx Configurations..." | pv -qL 25; echo -e "-Generating Nginx Configurations..." >> $logfile  2>&1

# HTTP Nginx Conf
echo "server {
	listen 80;
	listen [::]:80;
	server_name ${DOMAIN_NAME};
	return 301 https://\$host\$request_uri;

	location ${GUAC_URIPATH} {
	proxy_pass http://${GUAC_SERVER_IP}:8080/guacamole/;
	proxy_buffering off;
	proxy_http_version 1.1;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header Upgrade \$http_upgrade;
	proxy_set_header Connection \$http_connection;
	proxy_cookie_path /guacamole/ ${GUAC_URIPATH};
	access_log off;
	}
}" > /etc/nginx/conf.d/guacamole.conf

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
	proxy_pass http://${GUAC_SERVER_IP}:8080/guacamole/;
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

# Enable/Start Nginx Service
sleep 1 | echo -e "\n${Bold}Enable & Start Nginx Service..." | pv -qL 25; echo -e "\nEnable & Start Nginx Service..." >> $logfile  2>&1
systemctl enable nginx >> $logfile 2>&1 || exit 1
systemctl start nginx >> $logfile 2>&1 || exit 1

sleep 1 | echo -e "${Bold}\nIf you need to understand the Nginx configurations please go to:\n ${Green} http://nginx.org/en/docs/ \n${Reset}${Bold}If you need to replace the certificate file please read first:\n ${Green} http://nginx.org/en/docs/http/configuring_https_servers.html ${Reset}"; echo -e "\nIf you need to understand the Nginx configurations please go to:\n  http://nginx.org/en/docs/ \nIf you need to replace the certificate file please read first:\n  http://nginx.org/en/docs/http/configuring_https_servers.html" >> $logfile  2>&1

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

# Append LDAP configuration lines to guacamole.properties
sleep 1 | echo -e "\n${Bold}Updating Guacamole configuration file for LDAP..." | pv -qL 25; echo -e "\nUpdating Guacamole configuration file for LDAP..." >> $logfile  2>&1
echo "
# LDAP properties
ldap-hostname: ${LDAP_HOSTNAME}
ldap-port: ${LDAP_PORT}" >> /etc/guacamole/${GUAC_CONF}

# LDAPS specific properties
if [ $SECURE_LDAP = true ]; then
	KS_PATH=$(find "/usr/lib/jvm/" -name "cacerts")
	keytool -storepasswd -new ${JKS_CACERT_PASSWD} -keystore ${KS_PATH} -storepass "changeit" 
	keytool -importcert -alias "ldaps" -keystore ${KS_PATH} -storepass ${JKS_CACERT_PASSWD} -file ${LDAPS_CERT_FULL} -noprompt >> $logfile  2>&1 &
	sleep 1 | echo -ne "${Reset}-Updating Guacamole configuration file for LDAPS...    " | pv -qL 25; echo -ne "Updating Guacamole configuration file for LDAPS...    " >> $logfile  2>&1 | spinner

	echo "ldap-encryption-method: ssl" >> /etc/guacamole/${GUAC_CONF}
fi

echo "ldap-user-base-dn: ${LDAP_BASE_DN}
ldap-search-bind-dn: ${LDAP_BIND_DN}
ldap-search-bind-password: ${LDAP_BIND_PW}
ldap-username-attribute: ${LDAP_UNAME_ATTR}
ldap-user-search-filter: ${LDAP_SEARCH_FILTER}" >> /etc/guacamole/${GUAC_CONF}

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

totpsetup () {
	echo "totpsetup"
}

duosetup () {
	echo "duosetup"
}

radiussetup () {
	echo "radiussetup"
}

cassetup () {
	echo "cassetup"
}

openidsetup () {
	echo "openidsetup"
}

#####    CUSTOM EXTENSION SETUP    ########################################
custsetup () {
# Copy Custom Extension to Extensions Directory
sleep 1 | echo -e "\n${Bold}Copying Custom Guacamole Extension to Extensions Dir..." | pv -qL 25; echo -e "\nCopying Custom Guacamole Extension to Extensions Dir..." >> $logfile  2>&1
mv -v ${CUST_FULL} ${LIB_DIR}extensions/ >> $logfile  2>&1 || exit 1
}

#####    SELINUX SETTINGS    ########################################
# Needs attention for other extension options
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

# MySQL Connector Extension Context
semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}lib/${MYSQL_CON}.jar" >> $logfile  2>&1
restorecon -v "${LIB_DIR}lib/${MYSQL_CON}.jar" >> $logfile  2>&1

# Guacamole LDAP Extension Context (If selected)
if [ $INSTALL_LDAP = true ]; then
	semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole TOTP Extension Context (If selected)
if [ $INSTALL_TOTP = true ]; then
	echo "totp true"
	#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole Duo Extension Context (If selected)
if [ $INSTALL_DUO = true ]; then
	echo "duo true"
	#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole RADIUS Extension Context (If selected)
if [ $INSTALL_RADIUS = true ]; then
	echo "radius true"
	#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole CAS Extension Context (If selected)
if [ $INSTALL_CAS = true ]; then
	echo "cas true"
	#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole OpenID Extension Context (If selected)
if [ $INSTALL_OPENID = true ]; then
	echo "openid true"
	#semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
	#restorecon -v "${LIB_DIR}extensions/${GUAC_LDAP}.jar" >> $logfile  2>&1
fi

# Guacamole Custom Extension Context (If selected)
if [ $INSTALL_CUST_EXT = true ]; then
	semanage fcontext -a -t tomcat_exec_t "${LIB_DIR}extensions/${CUST_FN}" >> $logfile  2>&1
	restorecon -v "${LIB_DIR}extensions/${CUST_FN}" >> $logfile  2>&1
fi

sestatus >> $logfile 2>&1

firewallsettings
}

#####    FIREWALL SETTINGS    ########################################
firewallsettings () {
sleep 1 | echo -e "\n${Bold}Setting Firewall..." | pv -qL 25; echo -e "\nSetting Firewall..." >> $logfile  2>&1
echo -e "Take Firewall RC...\n" >> $logfile  2>&1
echo -e "rpm -qa | grep firewalld" >> $logfile  2>&1
rpm -qa | grep firewalld >> $logfile  2>&1
RETVALqaf=$?
echo -e "\nservice firewalld status" >> $logfile  2>&1
systemctl status firewalld >> $logfile  2>&1
RETVALsf=$?

if [ $RETVALsf -eq 0 ]; then
	sleep 1 | echo -e "${Reset}-firewalld is installed and started on the system" | pv -qL 25; echo -e "...firewalld is installed and started on the system" >> $logfile  2>&1
elif [ $RETVALqaf -eq 0 ]; then
	sleep 1 | echo -e "${Reset}-firewalld is installed but not enabled or started on the system" | pv -qL 25; echo -e "-firewalld is installed but not enabled or started on the system" >> $logfile  2>&1
	
	systemctl enable firewalld
	systemctl start firewalld
fi

echo -e "\nMaking Firewall Backup...\ncp /etc/firewalld/zones/public.xml $fwbkpfile" >> $logfile  2>&1
cp /etc/firewalld/zones/public.xml $fwbkpfile >> $logfile 2>&1

# Open HTTP and HTTPS ports
sleep 1 | echo -e "${Reset}-Opening ports 80 and 443" | pv -qL 25; echo -e "-Opening ports 80 and 443" >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=http" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-service=http >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-service=https" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-service=https >> $logfile  2>&1

# Open 8080 and 8443 ports. Need to review if this is required or not
sleep 1 | echo -e "${Reset}-Opening ports 8080 and 8443" | pv -qL 25; echo -e "-Opening ports 8080 and 8443" >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8080/tcp" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-port=8080/tcp >> $logfile  2>&1
echo -e "Add new rule...\nfirewall-cmd --permanent --zone=public --add-port=8443/tcp" >> $logfile  2>&1
firewall-cmd --permanent --zone=public --add-port=8443/tcp >> $logfile  2>&1

echo -e "Reload firewall...\nfirewall-cmd --reload\n" >> $logfile  2>&1
firewall-cmd --reload >> $logfile  2>&1

sslcerts
}

#####    SSL CERTIFICATE        ########################################
sslcerts () {

if [ $SSL_CERT_TYPE != "None" ]; then
	# Lets Encrypt Setup (If selected)
	if [ $SSL_CERT_TYPE = "LetsEncrypt" ]; then
		yum install -y certbot python2-certbot-nginx >> $logfile 2>&1 &
		sleep 1 | echo -e "\n${Bold}Downloading certboot tool...    " | pv -qL 25; echo -e "\nDownloading certboot tool...\n" >> $logfile 2>&1 | spinner
		
		sleep 1 | echo -e "\n${Bold}Generating a ${CERTYPE} SSL Certificate...\n" | pv -qL 25; echo -e "\nGenerating a ${CERTYPE} SSL Certificate...\n" >> $logfile  2>&1
		certbot certonly --nginx -n --agree-tos --rsa-key-size ${LE_KEY_SIZE} -m "${EMAIL_NAME}" -d "${DOMAIN_NAME}" | tee -a $logfile
		
		ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" /etc/nginx/guacamole.crt || true >> $logfile 2>&1
		ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem" /etc/nginx/guacamole.key || true >> $logfile 2>&1
		ln -vs "/etc/letsencrypt/live/${DOMAIN_NAME}/chain.pem" /etc/nginx/guacamole.pem || true >> $logfile 2>&1

		#Setup automatic renewal
		systemctl enable certbot-renew.service >> $logfile 2>&1
		systemctl enable certbot-renew.timer >> $logfile 2>&1
		systemctl list-timers --all | grep certbot >> $logfile 2>&1
	else # Use a Self-Signed Cert
		sleep 1 | echo -e "\n${Bold}Please complete the Wizard for the ${CERTYPE} SSL Certificate...${Reset}" | pv -qL 25; echo -e "\nPlease complete the Wizard for the ${CERTYPE} SSL Certificate..." >> $logfile  2>&1
		
		openssl req -x509 -sha512 -nodes -days 365 -newkey rsa:${SSL_KEY_SIZE} -keyout /etc/nginx/guacamole.key -out /etc/nginx/guacamole.crt | tee -a $logfile
	fi

	sleep 1 | echo -e "\n${Bold}Enabling SSL Certificate in config...\n" | pv -qL 25; echo -e "\nEnabling SSL Certificate in config...\n" >> $logfile  2>&1
	sed -i 's/#\(.*ssl_.*certificate.*\)/\1/' /etc/nginx/conf.d/guacamole_ssl.conf >> $logfile 2>&1
	HTTPS_ENABLED=true
else # None
	sleep 1 | echo -e "\n${Bold}Skipping SSL Certificate in config...\n" | pv -qL 25; echo -e "\nSkipping SSL Certificate in config...\n" >> $logfile  2>&1
	
	# Cannot force/use HTTPS without a cert
	sed -i '/\(return 301 https\)/s/^/#/' >> $logfile 2>&1
	HTTPS_ENABLED=false
fi

showmessages
}

#####    COMPLETION MESSAGES    ########################################
showmessages () {

sleep 1 | echo -e "\n${Bold}Restarting all services" | pv -qL 25; echo -e "\nRestarting all services" >> $logfile  2>&1

systemctl restart tomcat >> $logfile 2>&1 || exit 1
systemctl restart guacd >> $logfile 2>&1 || exit 1
systemctl restart mariadb >> $logfile 2>&1 || exit 1
systemctl restart nginx >> $logfile 2>&1 || exit 1

sleep 1 | echo -e "\n${Bold}Finished Successfully" | pv -qL 25; echo -e "\nFinished Successfully" >> $logfile  2>&1
sleep 1 | echo -e "${Reset}You can check the log file at ${logfile}" | pv -qL 25; echo -e "You can check the log file at ${logfile}" >> $logfile  2>&1
sleep 1 | echo -e "${Reset}Your firewall backup file at ${fwbkpfile}"; echo -e "Your firewall backup file at ${fwbkpfile}" >> $logfile  2>&1

if [ ${DOMAIN_NAME} = "localhost" ]; then
	GUAC_URL=${GUAC_SERVER_IP}${GUAC_URIPATH}
else
	GUAC_URL=${DOMAIN_NAME}${GUAC_URIPATH}
fi

if [ ${HTTPS_ENABLED} = true ]; then
	HTTPS_MSG=" or https://${GUAC_URL}"
else
	HTTPS_MSG=". Without a cert, HTTPS is not available."
fi

sleep 1 | echo -e "\n${Bold}To manage Guacamole go to http://${GUAC_URL}${HTTPS_MSG}"; echo -e "\nTo manage Guacamole go to http://${GUAC_URL}${HTTPS_MSG}" >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}The default username and password are: ${Red}guacadmin${Reset}"; echo -e "\nThe default username and password are: guacadmin" >> $logfile  2>&1
sleep 1 | echo -e "${Red}Its highly recommended to create an admin account in Guacamole and disable/delete the default asap!${Reset}"; echo -e "Its highly recommended to create an admin account in Guacamole and disable/delete the default asap!" >> $logfile  2>&1
sleep 1 | echo -e "\n${Green}While not required, you may consider a reboot after verifying install${Reset}" | pv -qL 25; echo -e "\nWhile not required, you may consider a reboot after verifying install" >> $logfile  2>&1
sleep 1 | echo -e "\n${Bold}Contact ${ADM_POC} with any questions or concerns regarding this script\n"; echo -e "\nContact ${ADM_POC} with any questions or concerns regarding this script\n" >> $logfile  2>&1

tput sgr0
exit 1
}

#####    START    ########################################
init_vars
src_menu
src_vars
db_menu
pw_menu
ssl_cert_type_menu
nginx_menu
ext_menu
cust_ext_menu
sum_menu
