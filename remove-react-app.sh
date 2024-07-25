#!/bin/bash

# Set up variables for server IP, user, and domains directory
SERVER="[INSERT_SERVER_IP]"
USER="[INSERT_USERNAME]"
APPS_DIRECTORY="/home/$USER/react-apps"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

read -p "App ID: " APP_ID
read -p "URL: " DOMAIN_NAME

# Disable site in Apache
if sudo a2dissite $DOMAIN_NAME > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Disabled site in Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot disable site in Apache"
fi

# Delete Apache config file
if sudo rm -f /etc/apache2/sites-available/$DOMAIN_NAME.conf && sudo rm -f /etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.conf; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted Apache config file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete Apache config file"
fi

# Delete app directory
if sudo rm -r $APPS_DIRECTORY/$APP_ID/; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted app directory"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete app directory"
fi

# Reload Apache
if sudo service apache2 reload; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Show confirmation messages
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD_RED}*** $APP_ID and $DOMAIN_NAME are now removed! ***${END_COLOR}\n"
echo -e " "
