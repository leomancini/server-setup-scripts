#!/bin/bash

# Set up variables
USER="leo"
REPOS_DIRECTORY="/home/$USER/repositories"
APPS_DIRECTORY="/home/$USER/react-apps"
DEFAULT_DOMAIN_FOR_SUBDOMAINS="leo.gd"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --app-id) APP_ID="$2"; shift ;;
        --domain-name) DOMAIN_NAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for APP_ID if not set by CLI flag
if [ -z "$APP_ID" ]; then
    read -p "Enter App ID: " APP_ID
fi

# Prompt for the domain name with the default value if not set by CLI flag
DEFAULT_DOMAIN_NAME="$APP_ID.$DEFAULT_DOMAIN_FOR_SUBDOMAINS"

# Prompt for DOMAIN_NAME if not set by CLI flag
if [ -z "$DOMAIN_NAME" ]; then
    read -p "URL (Default: "${DEFAULT_DOMAIN_NAME}"): " DOMAIN_NAME
fi
DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}

# Validate inputs
if [ -z "$APP_ID" ]; then
    echo "Error: App ID is required."
    exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: Domain Name is required."
    exit 1
fi

# Function to clean inputs
clean_input() {
    echo "$1" | tr -d '\r'
}

# Clean inputs
APP_ID=$(clean_input "$APP_ID")
DOMAIN_NAME=$(clean_input "$DOMAIN_NAME")

echo " "

# Display the collected information
echo "App ID: $APP_ID"
echo "Domain Name: $DOMAIN_NAME"

echo " "

# Prompt for sudo password
read -s -p "Enter sudo password: " SUDO_PASSWORD
echo

# Function to keep sudo session alive
keep_sudo_alive() {
    while true; do
        echo "$SUDO_PASSWORD" | sudo -S -v > /dev/null 2>&1
        sleep 60
    done
}

echo " "

# Initial check to see if the provided password is correct
if ! echo "$SUDO_PASSWORD" | sudo -kS echo > /dev/null 2>&1; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} Password incorrect"
    echo " "
    exit 1
fi

# Start the keep-alive function in the background
keep_sudo_alive &
SUDO_KEEP_ALIVE_PID=$!

# Make sure to kill the keep-alive process on exit
trap 'kill $SUDO_KEEP_ALIVE_PID' EXIT

echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Password correct"

# Disable site in Apache
if sudo a2dissite "$DOMAIN_NAME" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Disabled site in Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot disable site in Apache"
fi

# Delete Apache config file
if sudo rm -f "/etc/apache2/sites-available/$DOMAIN_NAME.conf" && sudo rm -f "/etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.conf"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted Apache config file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete Apache config file"
fi

# Delete repository directory
if sudo rm -r "$REPOS_DIRECTORY/$APP_ID.git"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted repository directory"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete repository directory"
fi

# Delete app directory
if sudo rm -r "$APPS_DIRECTORY/$APP_ID/"; then
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
echo -e "${BOLD_RED}*** $APP_ID is now removed! ***${END_COLOR}\n"
echo -e " "
