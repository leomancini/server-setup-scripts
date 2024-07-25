#!/bin/bash

# Set up variables for server IP, user, and domains directory
SERVER="[INSERT_SERVER_IP]"
USER="[INSERT_USERNAME]"
SERVICES_DIRECTORY="/home/$USER/services"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

echo What is the combined service and domain name, including TLD?
read SERVICE_AND_DOMAIN

# Disable site in Apache
if sudo a2dissite $SERVICE_AND_DOMAIN > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Disabled site in Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot disable site in Apache"
fi

# Remove Apache config file
if sudo rm -f /etc/apache2/sites-available/$SERVICE_AND_DOMAIN.conf && sudo rm -f /etc/apache2/sites-available/$SERVICE_AND_DOMAIN-le-ssl.conf; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Removed Apache config file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot remove Apache config file"
fi

# Delete site directory
if sudo rm -r $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted site directory"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete site directory"
fi

# Stop node process
if pkill -f "node.*$SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/" > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Stopped node process"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot stop node process"
fi

# Reload Apache
if sudo service apache2 reload; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"

echo -e "${BOLD_RED}*** $SERVICE_AND_DOMAIN is now removed! ***${END_COLOR}\n"

echo -e " "
