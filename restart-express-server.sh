#!/bin/bash

# Set up variables
USER="leo"
SERVICES_DIRECTORY="/home/$USER/services"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
BOLD_CYAN='\e[1;36m'
END_COLOR='\e[0m' # This ends formatting

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="/home/$USER/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service-id) SERVICE_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for SERVICE_ID if not set by CLI flag
if [ -z "$SERVICE_ID" ]; then
    read -p "Service ID: " SERVICE_ID
fi

# Function to clean SERVICE_ID
clean_service_id() {
    echo "$1" | tr -d '\r'
}

# Clean SERVICE_ID
SERVICE_ID=$(clean_service_id "$SERVICE_ID")

# Sudo password: use DREAMCOMPUTE_LEO_PASSWORD env var or prompt
if [ -n "${DREAMCOMPUTE_LEO_PASSWORD:-}" ]; then
  SUDO_PASSWORD="$DREAMCOMPUTE_LEO_PASSWORD"
else
  read -s -p "Enter sudo password: " SUDO_PASSWORD
  echo
fi

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

# Find the DOMAIN_NAME from setup-log.json
SETUP_LOG_FILE="$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json"
if [ -f "$SETUP_LOG_FILE" ]; then
    DOMAIN_NAME=$(jq -r '.domain' "$SETUP_LOG_FILE" | sed 's|https://||')
    if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" == "null" ]; then
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find domain name in setup-log.json"
        exit 1
    else
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Found domain name $DOMAIN_NAME in setup-log.json "
    fi
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find file setup-log.json"
    exit 1
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Build if a build script exists
if node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts.build ? 0 : 1)" 2>/dev/null; then
    if npm run build; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Built for production"
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot build for production"
    fi
fi

# Kill any stale process on the port before restarting
PORT=$(jq -r '.port' "$SETUP_LOG_FILE")
if [ -n "$PORT" ] && [ "$PORT" != "null" ]; then
    STALE_PID=$(lsof -ti :$PORT -sTCP:LISTEN 2>/dev/null)
    if [ -n "$STALE_PID" ]; then
        echo "Killing stale process on port $PORT (PID $STALE_PID)"
        kill -9 "$STALE_PID" 2>/dev/null
        sleep 1
    fi
fi

# Restart via PM2
if pm2 restart "$SERVICE_ID" && pm2 save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Restarted $SERVICE_ID via PM2"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot restart $SERVICE_ID via PM2"
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
echo -e "${BOLD_CYAN}*** $SERVICE_ID has been restarted! ***${END_COLOR}\n"
echo -e " "
