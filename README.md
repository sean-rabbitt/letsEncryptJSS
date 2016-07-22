# letsEncryptJSS
Bash script for automating the generation and renewal of SSL certificates from Lets Encrypt for the JAMF Software Server (JSS) and Tomcat

Lets Encrypt (https://letsencrypt.org) is a free and automated way to install SSL certificates into several different types of web servers. Since the JAMF Software Server (JSS) runs off of Tomcat (a web server) I took it upon myself to figure out how to automate the request and installation of the proper certs. This is mainly due to folks running JSS instances without trusted certs and leaving themselves open to potential man in the middle attacks. 

# Awknowledgements
Based off of Ivan Tichy - http://blog.ivantichy.cz/blogpost/view/74 and Jon Yergatian - https://github.com/sonofiron

# Requreiments
This script will pull the latest copy of Lets Encrypt and configure it for your JSS. Please read though the entire script before running it. It is highly recomended that you test this on a development envronment before trying in production.

You must have the following software packages installed:
* Git
* Java
* JSS (Tomcat)

This script must be run with sudo.

If you have restrictive firewall rules, port 80 must be open from server out to the internet. LetsEncrypt uses port 80 to validate certs. Addiitionally, certs may only be renewed every 60-90 days (this is accounted for in the script).

#How to use

1. Ensure the JSS is running and that you can access the web console
2. Review and modify variables below. Stop before the script logic section
3. Copy script to JSS server and place in a safe place (not tmp)
4. run chmod +x /path/to/letsEncrypt.sh
5. run sudo bash /path/to/letsEncrypt.sh
6. (Optional) Place in /etc/cron.daily/ for the script to run automatically
  a. Change ownership of the file
  b. Change file permissions

Pleave me feedback and comments on how this could be improved!
Thanks ~ Kyle
