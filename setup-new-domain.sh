#!/bin/bash

# Set up variables
SERVER="root.noshado.ws"
USER="leo"
ADMIN_CONTACT="www@noshado.ws"
DOMAINS_DIRECTORY="/home/$USER/domains"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

echo What is the domain name, including TLD?
read DOMAIN_NAME

# Create root directory for domain
if sudo mkdir $DOMAINS_DIRECTORY/$DOMAIN_NAME; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $DOMAINS_DIRECTORY/$DOMAIN_NAME"
else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $DOMAINS_DIRECTORY/$DOMAIN_NAME"
fi

# Create public html directory
if sudo mkdir $DOMAINS_DIRECTORY/$DOMAIN_NAME/html; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created public html directory at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html"
else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create public html directory at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html"
fi

# Change permissions for domain directory to specified user
if sudo chown -R $USER $DOMAINS_DIRECTORY/$DOMAIN_NAME; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions of $DOMAINS_DIRECTORY/$DOMAIN_NAME to $USER"
else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions of $DOMAINS_DIRECTORY/$DOMAIN_NAME to $USER"
fi

# If an index.html file doesn't exist, create a placeholder one
if [ ! -f $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html ]; then
	touch $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html

	if echo "$DOMAIN_NAME" | sudo tee $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html > /dev/null; then
	        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created placeholder index.html at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html"
	else
	        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create placeholder index.html at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html"
	fi
else
	echo -e "${BOLD}PASSED${END_COLOR} Did not create placeholder index.html, file already exists at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html"
fi

# Optional: Pick PHP version
read -r -p "Do you want to use legacy PHP version 5.6 for $DOMAIN_NAME? [y/N] " USE_LEGACY_PHP
if [[ "$USE_LEGACY_PHP" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	echo -e "${BOLD}LEGACY PHP${END_COLOR} Using legacy PHP 5.6 for $DOMAIN_NAME"
	
	LEGACY_PHP_VIRTUALHOST_ADDON="
    <FilesMatch \.php$>
        SetHandler 'proxy:unix:/var/run/php/php5.6-fpm.sock|fcgi://localhost/'
    </FilesMatch>
"
else
	echo -e "${BOLD}NEW PHP${END_COLOR} Using default PHP version for $DOMAIN_NAME"
	
	LEGACY_PHP_VIRTUALHOST_ADDON=""
fi

# Create a VirtualHost config file that points to the domain directory
sudo touch /etc/apache2/sites-available/$DOMAIN_NAME.conf
if echo "<VirtualHost *:80>
	
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT
    DocumentRoot $DOMAINS_DIRECTORY/$DOMAIN_NAME/html
    
    <Directory $DOMAINS_DIRECTORY/$DOMAIN_NAME/html>
        AllowOverride all
        Require all granted
    </Directory>
	$LEGACY_PHP_VIRTUALHOST_ADDON
    ErrorLog /var/log/apache2/$DOMAIN_NAME-error.log
    CustomLog /var/log/apache2/$DOMAIN_NAME-access.log combined
	
</VirtualHost>" | sudo tee /etc/apache2/sites-available/$DOMAIN_NAME.conf > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"
fi

# Enable site in Apache
if sudo a2ensite $DOMAIN_NAME > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Enabled site $DOMAIN_NAME in Apache"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot enable site $DOMAIN_NAME in Apache"
fi

# Reload Apache
if sudo service apache2 reload; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Optional: Generate SSL certificate from Let's Encrypt
read -r -p "Do you want to setup HTTPS with Let's Encrypt? [y/N] " SSL_CERTIFICATE_SETUP
if [[ "$SSL_CERTIFICATE_SETUP" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	echo "Generating certificate with Let's Encrypt for $DOMAIN_NAME"
	sudo certbot --apache -d $DOMAIN_NAME,www.$DOMAIN_NAME
	
	HTTPS="true"
else
	echo -e "${BOLD}PASSED${END_COLOR} Not setting up HTTPS for $DOMAIN_NAME"
	
	HTTPS="false"
fi

# Optional: Set up a bare Git repository in the domain directory
read -r -p "Do you want to setup a Git repository for $DOMAIN_NAME? [y/N] " GIT_SETUP
if [[ "$GIT_SETUP" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	
	# Remove placeholder file if setting up a Git repository to ensure working directory is empty
	if sudo rm $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html; then
		echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Removed placeholder index.html at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html"
	else
		echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot remove placeholder index.html at $DOMAINS_DIRECTORY/$DOMAIN_NAME/html/index.html"
	fi
	
	# Initialize empty Git repository
	if git init --bare $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git; then
		echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created empty Git repository at $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git"
	else
		echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create empty Git repository at $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git"
	fi
	
	# Set up a hook that deploys any commits made to this repo to the working directory 
	sudo touch $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git/hooks/post-receive
	sudo chmod +x $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git/hooks/post-receive

	if echo "#!/bin/bash
echo -e \"${BOLD_GREEN}SUCCESS${END_COLOR} Deployed master to $DOMAINS_DIRECTORY/$DOMAIN_NAME/html\"
git --work-tree=$DOMAINS_DIRECTORY/$DOMAIN_NAME/html --git-dir=$DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git checkout -f" | sudo tee $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git/hooks/post-receive > /dev/null; then
		echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook at $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git/hooks/post-receive"
	else
		echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook at $DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git/hooks/post-receive"
	fi
	
	GIT="true"
else
	echo -e "${BOLD}PASSED${END_COLOR} Not setting up Git repository for $DOMAIN_NAME"
	
	GIT="false"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD}*** $DOMAIN_NAME is now set up! ***${END_COLOR}\n"

if [[ $HTTPS == "true" ]]; then
	echo -e "* Visit ${BOLD}https://$DOMAIN_NAME${END_COLOR} to see the new site"
else
	echo -e "* Visit ${BOLD}http://$DOMAIN_NAME${END_COLOR} to see the new site"
fi

if [[ $GIT == "true" ]]; then
	echo -e "\n* Add this remote to deploy: \n${BOLD}git remote add web $USER@$SERVER:$DOMAINS_DIRECTORY/$DOMAIN_NAME/$DOMAIN_NAME.git${END_COLOR}"
fi

echo -e " "
