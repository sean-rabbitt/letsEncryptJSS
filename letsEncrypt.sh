#!/bin/bash

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Written by Kyle Bareis
# Updated by Sean Rabbitt, Rob Potvin, and Matt DiRose

# Based off of Ivan Tichy - http://blog.ivantichy.cz/blogpost/view/74
# Based off of Jon Yergatian - https://github.com/sonofiron

####### Requreiments #######

# This script will pull the latest copy of Lets Encrypt and configure it for your JSS
# Please read though the entire script before running this. It is highly recomended
# That you test this on a development envronment before trying in production.

# You must have the following software packages installed:
#	* Git
#	* Java
#	* JSS (Tomcat)

# This script must be run with sudo.

# If you have restrictive firewall rules, port 80 must be open from server out to
# the internet. LetsEncrypt uses port 80 to validate certs. Addiitionally, certs
# may only be renewed every 60-90 days.

####### How to use #######

# 1. Ensure the JSS is running and that you can access the web console
# 2. Review and modify variables below. Stop before the script logic section
# 2.5 - If you are using a non-standard installation of tomcat, check the variable JSS_KEYSTORE_LOCATION located at the very beginning of the script logic section.  The script assumes that the file is in /usr/local/jss/tomcat/.  If it is in a non-standard location, change this line or simply hardcode the location of the file by adding:
#	JSS_KEYSTORE_LOCATION=/path/to/keystore/location/.file
#	after the script logic or by replacing that logic completely.
# 3. Copy script to JSS server and place in a safe place (not tmp)
# 4. run chmod +x /path/to/letsEncrypt.sh
# 5. run sudo bash /path/to/letsEncrypt.sh
# 6. (Optional) Place in /etc/cron.daily/ for the script to run automatically
#		6.a Change ownership of the file
#		6.b Change file permissions
# 	6.c Remove .sh from script. Validate setup by running: run-parts --test /etc/cron.daily

####### Variables #######

# FQDN of the JSS. This cannot be a .local domain
	DOMAIN="jss.company.com"

# Email address used to sign the cert. Renewal notices will be sent to this address.
	EMAIL="you@domain.com"

# JSS Tomcat Service (default is jamf.tomcat8 for Casper Suite 9.93). May need to
# be changed if JSS was manually installed or if there is a different verison of
# Tomcat.
	JSS_SERVICE="jamf.tomcat8"

# JSS (Tomcat) Server XML file location
	JSS_SERVER_XML="/usr/local/jss/tomcat/conf/server.xml"

# Location of the Lets Encrypt binary.
	LETSENCRYPT_LOCATION="/var/git/letsencrypt"

# Lets Encrypt password for .pem file
# This is a password for the holding container that we generate certs into.
# While this is not an outward facing cert file, it is recomended that you use
# a secure password. This will only be used by this script.
	LETSENCRYPT_STOREPASS="changeit"

# Log file location
	LOG="/tmp/letsEncryptConsole.log"
	
# JSS Keystore Location - If the keystore is not in /usr/local/jss/tomcat, the 
# default loation, change line 79 below.

####### Script Logic #######

# JSS keystore location read from the server.xml file
# Assuming keystore is in /usr/local/jss/tomcat/. Must change if different. Thanks @SeanRabbit
	JSS_KEYSTORE_LOCATION="/usr/local/jss/tomcat/$(sed -n 's/^.*certificateKeystoreFile=/certificateKeystoreFile=/p' $JSS_SERVER_XML | cut -d '"' -f2 | cut -d '/' -f2)"

# JSS keystore password read from the server.xml file
	JSS_STOREPASS=$(sed -n 's/^.*certificateKeystorePassword=/certificateKeystorePassword=/p' $JSS_SERVER_XML | cut -d '"' -f2)

# Checking to see if required services are installed. For each service in the
# array, the for loop will look to see if it can find the binary. If it can't
# the script will exit.
	REQUIRED_SERVICES=("git" "java" "keytool" "openssl")
	for SERVICE in "${REQUIRED_SERVICES[@]}"; do
		if type -p "$SERVICE"; then
			echo "$(date "+%a %h %d %H:%M:%S"): $SERVICE installed" 2>&1 | tee -a "$LOG"
		else
			echo "$(date "+%a %h %d %H:%M:%S"): Could not find $SERVICE installed. Exiting script!" 2>&1 | tee -a "$LOG"
			exit 1
		fi
	done

# Checking to see if the JSS is installed and running. If not, it will exit
	if [ ! -f "$JSS_KEYSTORE_LOCATION" ]; then
		echo "$(date "+%a %h %d %H:%M:%S"): Unable to find the JSS keystore at $JSS_KEYSTORE_LOCATION. Exiting script!" 2>&1 | tee -a "$LOG"
		exit 1
	else
		echo "$(date "+%a %h %d %H:%M:%S"): Keystore found. JSS appears to be installed." 2>&1 | tee -a "$LOG"
	fi

# Creating folder structure for Git and Lets Encrypt. If the folder for Lets
# Encrypt is not found, a new folder will be created and the Git repo will be
# downloaded to that location.
	if [ -d  "$LETSENCRYPT_LOCATION" ]; then
		echo "$(date "+%a %h %d %H:%M:%S"): Lets Encrypt directory already present." 2>&1 | tee -a "$LOG"
	else
		echo "$(date "+%a %h %d %H:%M:%S"): Git'in Lets Encrypt and placing it in $LETSENCRYPT_LOCATION" 2>&1 | tee -a "$LOG"
		mkdir -p /var/git
		git clone https://github.com/letsencrypt/letsencrypt "$LETSENCRYPT_LOCATION"
	fi

# First if loop is for checking to see if certificates have already been cofingured.
# If certs have been configured, then the script will check and see if they need to
# be renewed and re-installed into the JSS's keystore.
	if [ -d /etc/letsencrypt/live/"$DOMAIN" ]; then
		echo "$(date "+%a %h %d %H:%M:%S"): Certificates for $DOMAIN are already generated. Checking date and time stamps." 2>&1 | tee -a "$LOG"
			# Running a comparision between todays date and the time stamp on the privkey
			# Certs can only be renewed max every 60 days from Lets Encrypt. Manually
			# renewing after 60 days.
				PRIVATE_KEY_DATE=$(date -r /etc/letsencrypt/live/"$DOMAIN"/privkey.pem +%Y%m%d)
				MIN_RENEWAL_DATE=$(date -d "$PRIVATE_KEY_DATE 60 days" +"%Y%m%d")
				TODAYS_DATE=$(date +"%Y%m%d")
				if [ "$TODAYS_DATE" -gt "$MIN_RENEWAL_DATE" ]; then
					echo "$(date "+%a %h %d %H:%M:%S"): Certificates can be updated. Updating manually." 2>&1 | tee -a "$LOG"
					"$LETSENCRYPT_LOCATION"/letsencrypt-auto renew
				else
					echo "$(date "+%a %h %d %H:%M:%S"): Certificates do not need to be updated. Next update needed after $MIN_RENEWAL_DATE" 2>&1 | tee -a "$LOG"
					exit 0
				fi
	else
		echo "$(date "+%a %h %d %H:%M:%S"): Certificates not found for $DOMAIN. Generating new cert request." 2>&1 | tee -a "$LOG"
		"$LETSENCRYPT_LOCATION"/letsencrypt-auto certonly --standalone -d "$DOMAIN" --renew-by-default --email "$EMAIL" --agree-tos
		# --standalone-supported-challenges http-01  is no longer supported command
	fi

# Generating a .pem file from the certs signed by Lets Encrypt. In order to
# export the certs for proper use with Tomcat, the files need to be placed in
# a .PEM file.
	echo "$(date "+%a %h %d %H:%M:%S"): Exporting certificates from Lets Encrypt" 2>&1 | tee -a "$LOG"
	openssl pkcs12 -export -in /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem -inkey /etc/letsencrypt/live/"$DOMAIN"/privkey.pem -out /etc/letsencrypt/live/"$DOMAIN"/cert_and_key.p12 -name tomcat -CAfile /etc/letsencrypt/live/"$DOMAIN"/chain.pem -caname tomcat -password pass:"$LETSENCRYPT_STOREPASS"

# Stopping Tomcat while making changes. The script will restart Tomcat when finished.
	CHECK_JSS_SERVICE=$(service --status-all | grep "$JSS_SERVICE" | cut -d ' ' -f6)
	if [ "$CHECK_JSS_SERVICE" = "$JSS_SERVICE" ]; then
		echo "$(date "+%a %h %d %H:%M:%S"): $JSS_SERVICE is running. Stopping service now." 2>&1 | tee -a "$LOG"
		service "$JSS_SERVICE" stop
	else
		echo "$(date "+%a %h %d %H:%M:%S"): $JSS_SERVICE not found. Exiting script!" 2>&1 | tee -a "$LOG"
		echo "$(date "+%a %h %d %H:%M:%S"): If this is your first time running this script, you will need to remove /etc/letsencrypt and /var/git/letsencrypt" 2>&1 | tee -a "$LOG"
		echo "$(date "+%a %h %d %H:%M:%S"): If this has worked before for you, please check and see if Tomcat is running." 2>&1 | tee -a "$LOG"
		exit 1
	fi

# Backing up the existing Keystore. This is primarily for safety. Never want to
# delete things unless you have a backup!
	echo "$(date "+%a %h %d %H:%M:%S"): Creating back up of keystore. Location: $JSS_KEYSTORE_LOCATION.old" 2>&1 | tee -a "$LOG"
	cp "$JSS_KEYSTORE_LOCATION" "$JSS_KEYSTORE_LOCATION.old"

# Removing any existing aliases within the Tomcat Keystore. We need to existing
# keystore for tomcat to be empty so this will remove every alias within the file
	TOMCAT_ALIAS=$(keytool -list -v --keystore "$JSS_KEYSTORE_LOCATION" -storepass "$JSS_STOREPASS" | grep Alias | cut -d ' ' -f3)

	for ALIAS in $TOMCAT_ALIAS; do
		echo "$(date "+%a %h %d %H:%M:%S"): Removing $ALIAS from $JSS_KEYSTORE_LOCATION" 2>&1 | tee -a "$LOG"
		keytool -delete -alias "$ALIAS" -storepass "$JSS_STOREPASS" -keystore "$JSS_KEYSTORE_LOCATION"
	done

# Importing Unique Tomcat Certificates
	echo "$(date "+%a %h %d %H:%M:%S"): Importing Tomcat Certicate" 2>&1 | tee -a "$LOG"
	keytool -importkeystore -srcstorepass "$LETSENCRYPT_STOREPASS" -deststorepass "$JSS_STOREPASS" -destkeypass "$JSS_STOREPASS" -srckeystore /etc/letsencrypt/live/"$DOMAIN"/cert_and_key.p12 -srcstoretype PKCS12 -alias tomcat -keystore "$JSS_KEYSTORE_LOCATION"

# Importing Chain Certificates
	echo "$(date "+%a %h %d %H:%M:%S"): Importing Chain Certificates" 2>&1 | tee -a "$LOG"
	keytool -import -trustcacerts -alias root -deststorepass "$JSS_STOREPASS" -file /etc/letsencrypt/live/"$DOMAIN"/chain.pem -noprompt -keystore "$JSS_KEYSTORE_LOCATION"

# Restarting Tomcat
	CHECK_JSS_SERVICE=""
	service "$JSS_SERVICE" start
	CHECK_JSS_SERVICE=$(service --status-all | grep "$JSS_SERVICE" | cut -d ' ' -f6)
	if [ "$CHECK_JSS_SERVICE" = "$JSS_SERVICE" ]; then
		echo "$(date "+%a %h %d %H:%M:%S"): $JSS_SERVICE is running." 2>&1 | tee -a "$LOG"
		exit 0
	else
		echo "$(date "+%a %h %d %H:%M:%S"): $JSS_SERVICE not found. Tomcat failed to restart. Exiting script!" 2>&1 | tee -a "$LOG"
		echo "$(date "+%a %h %d %H:%M:%S"): You must manually put back your old keystore $JSS_KEYSTORE_LOCATION.old" 2>&1 | tee -a "$LOG"
		exit 1
	fi

# Successful exit code
	echo "$(date "+%a %h %d %H:%M:%S"): Script sucessfull!" 2>&1 | tee -a "$LOG"
	exit 0
