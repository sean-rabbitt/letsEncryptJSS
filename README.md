# Lets Encrypt for JSS (JAMF Software Server)
Bash script for automating the generation and renewal of SSL certificates from Lets Encrypt for the JAMF Software Server (JSS) and Tomcat

Lets Encrypt (https://letsencrypt.org) is a free and automated way to install SSL certificates into several different types of web servers. Since the JAMF Software Server (JSS) runs off of Tomcat (a web server) I took it upon myself to figure out how to automate the request and installation of the proper certs. This is mainly due to folks running JSS instances without trusted certs and leaving themselves open to potential man in the middle attacks.

## Acknowledgements
Based off of Ivan Tichy - http://blog.ivantichy.cz/blogpost/view/74 and Jon Yergatian - https://github.com/sonofiron

## Requirements
This script will pull the latest copy of Lets Encrypt and configure it for your JSS. Please read though the entire script before running it. It is highly recommend that you test this on a development environment before trying in production.

You must have the following software packages installed:
* Git
* Java
* JSS (Tomcat)

This script must be run with sudo.

If you have restrictive firewall rules, port 80 must be open from server out to the internet. LetsEncrypt uses port 80 to validate certs. Additionally, certs may only be renewed every 60-90 days (this is accounted for in the script).

## How to use

1. Ensure the JSS is running and that you can access the web console
2. Review and modify variables above the script logic. Stop before the script logic section
2.5 - If you are using a non-standard installation of tomcat, check the variable JSS_KEYSTORE_LOCATION located at the very beginning of the script logic section.  The script assumes that the file is in /usr/local/jss/tomcat/.  If it is in a non-standard location, change this line or simply hardcode the location of the file by adding:
	JSS_KEYSTORE_LOCATION=/path/to/keystore/location/.file
	after the script logic or by replacing that logic completely.
3. Copy script to JSS server and place in a safe place (not tmp)
4. run chmod +x /path/to/letsEncrypt.sh
5. run sudo bash /path/to/letsEncrypt.sh
6. (Optional) Place in /etc/cron.daily/ for the script to run automatically. Change ownership of the file and permissions to match. Also make sure to leave off .sh from the script. You can validate that the script will be run with this command: run-parts --test /etc/cron.daily

### Known Issues
If you were running an older verion of the script, you may receive a message like:
Renewal configuration file /etc/letsencrypt/renewal/jamf.stoutcs.com.conf (cert: jamf.domainname.com) produced an unexpected error: 'Namespace' object has no attribute 'standalone_supported_challenges'. Skipping.
The certificate was created with an older version of certbot, and the flag --standalone-supported-challenges http-01  is no longer supported command.
To fix this problem, the easiest method is to create an entirely new certificate.  (Hey, they're free, right?)
	1) sudo mv /etc/letsencrypt ~/letsencryptold
	2) Upgrade to the latest version of the script
	3) Run to create a brand new certificate.

Please leave feedback and/or comments on how this could be improved!  And many thanks to Kyle for making this script to begin with.  We miss you!

Thanks! Sean
