# Apache Guacamole Install Script for RHEL 7 and CentOS 7
The Guacamole install script `guac-install.sh` is intended to allow for a guided, simple way to install and configure a complete Apache Guacamole server on a fresh CentOS 7 or RHEL 7 installation. This Apache Guacamole installation script presents an interactive menu providing options to install Guacamole, Nginx, MariaDB and other software for a complete Guacamole setup. The menu provides the means to set configuration parameters in an organized way, allows for review and making changes prior to running the installation for Guacamole.

The [wiki](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki) will cover all aspects of the Apache Guacamole installation script for RHEL and CentOS in further detail. Before using the script read all the documentation and review the Guacamole install script (especially the variables). Test the Guacamole script in a test environment/server and ensure it functions exactly as desired before attempting to utilize it on a production system.

Some of the main features and benefits of using this installation script for Apache Guacamole are:
- Simplifies the process of installing Apache Guacamole and other software required for a complete implementation.
- Use of Nginx as a reverse proxy allows for changing the URI, having SSL/HTTPS securely setup and forcing HTTPS among other benefits.
- Nginx configuration options capable of scoring A+ and 90-100% on the categories of the Qualys SSL test. Will varying based on other options selected.
- Nginx Content-Security-Policy (CSP) option to enable CSP. Scores A+, 100/100 on Mozilla Observatory test.
- Ability to create a valid SSL certificate from LetsEncrypt AND keep it updated automatically. Also allows setting the key-size used by LetsEncrypt.
- MariaDB is setup and configured as the database for user settings and metadata. MariaDB is the default primary authentication method.
- MariaDB is also automatically hardened (by running mysql_secure_installation and automatically answering the prompts)
- Ability to install and configure Guacamole extensions for primary and secondary authentication. (Currently limited to LDAP(s) and/or TOTP)
- Ability to install a custom Guacamole extension, like my [Guacamole Customize Login Page extension](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Customizing-the-Apache-Guacamole-Login-Screen) to change the appearance of the login page.
- Optionally, LDAP/LDAPS as primary authentication via Guacamole LDAP extension and configuration prompts.
- Optionally, TOTP as a 2FA method via Guacamole TOTP extension and configuration prompts.
- All SELinux contexts properly set instead of disabling SEL.
- Firewalld configured for Guacamole.
- Script generates a log file of what it did for review.
- Error handling covering the installation process. On error the line number, line that failed and exit code are displayed, logged and the script stops
- And more...

Further details see the [Script Features](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Guacamole-Install-Script-Features) page.

## Requirements to Run the Guacamole Install Script Successfully
- Install RHEL 7.x or CentOS 7.x and up using either minimal install or Server with GUI.
- `wget` installed to download the Guacamole install script `guac-install.sh` from this repo.
- The server must have internet access to download the script and files required by Apache Guacamole that are acquired and installed by this script.
- Sudo or root access on the RHEL or CentOS server, script requires being run as sudo/root.
- If using RHEL, an activated subscription for access to its repos.
- **No prior Guacamole installation or configuration including for its major dependent packages like Nginx, Tomcat, mariaDB, etc. IE: if the script fails, you cannot simply re-run it! Also, this script cannot be used to update a previous Guacamole install!!**
- SELinux must be enabled and in "Enforcing mode" or the script will not run.

Full requirements listed on the [Requirements](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Requirements) page

## "Required" Reading
I recommend reading this entire README page AND the entire [Wiki](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki) prior to attempting to use the Apache Guacamole installation script. It is essential to understand what the script does as you will be prompted to enter parameters during setup when running the script. It is important to be prepared to answer these prompts with accurate and desired parameters.

Of special importance to starting with this Guacamole install script are:
- [Warnings](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Warnings)
- [Logs & Error Handling](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Logs-&-Error-Handling)
- [Testing Procedure](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Testing-Procedure)
- [Troubleshooting](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Troubleshooting)
- [How to Report an Issue](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/How-to-Report-Issues-(Bugs,-Feature-Request-and-Help))

## Download/Run the Apache Guacamole Script for RHEL 7 and CentOS 7
**WARNING: It is highly recommended to test this script in a dev environment prior to using it in a production setting!**

Download the `guac-install.sh` script from this repo:
```
wget https://raw.githubusercontent.com/Zer0CoolX/guacamole-install-rhel/master/guac-install.sh
```
If installing a custom Guacamole extension, download it as well and take note of its file name and path. See [here](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Customizing-the-Apache-Guacamole-Login-Screen) for more details

Make the `guac-install.sh` script executable:
```
chmod +x guac-install.sh
```
Run the script as sudo/root:
```
./guac-install.sh
```
Proceed with the prompts provided by the installer, see [Step-by-Step Installation Guide](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Step-by-Step-Installation-Guide) for a walk-through of the options.

## Customizing the Apache Guacamole login screen
See this wiki post regarding [Customizing the Apache Guacamole Login Screen](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/Customizing-the-Apache-Guacamole-Login-Screen) for details on another repo of mine to accomplish this.

## Apache Guacamole Install Script Information
I have based this Apache Guacamole install script on multiple other projects and my own work with similar goals. There are too many sources to provide credit to.

The script versioning, for now, will be based on the date of the last commit in the format "yyyy_mm_dd".

I try and test the script as many ways as I can. Should you find an issue you feel is due to the script please submit an issue according to the directions [here](https://github.com/Zer0CoolX/guacamole-install-rhel/wiki/How-to-Report-Issues-(Bugs,-Feature-Request-and-Help)). I am also open to ideas on improving or fixing issues with the script. I am hoping that in time, after revisions and testing, that this install script for Guacamole will become the go-to for those looking to setup Guacamole on RHEL or CentOS.

Thanks

As expressed on the official site for [Apache Guacamole](https://guacamole.apache.org/) (which is free and open source):
> Apache Guacamole is a clientless remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH. We call it clientless because no plugins or client software are required.

[Nginx](https://nginx.org/en/) is a free and open source HTTP and reverse proxy server.

[MariaDB](https://mariadb.org/) is an open source database that is forked from MySQL.

[Let's Encrypt](https://letsencrypt.org/) is a free, automated and open Certificate Authority providing SSL certificates to allow setting up more secure websites using HTTPS.
