#!/bin/bash

# Set up variables
SERVER="root.noshado.ws"
USER="leo"
ADMIN_CONTACT="www@noshado.ws"
REPOS_DIRECTORY="/home/$USER/repositories"
APPS_DIRECTORY="/home/$USER/react-apps"
DEFAULT_DOMAIN_FOR_SUBDOMAINS="leo.gd"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="/home/$USER/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Parse CLI arguments
CLI_ID="" CLI_DOMAIN=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --app-id) CLI_ID="$2"; shift 2 ;;
    --domain) CLI_DOMAIN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# App ID: use CLI arg or prompt
if [ -n "$CLI_ID" ]; then
  APP_ID="$CLI_ID"
else
  read -p "App ID: " APP_ID
fi

# Domain: use CLI arg, auto-derive if app-id was given via CLI, or prompt
if [ -n "$CLI_DOMAIN" ]; then
  DOMAIN_NAME="$CLI_DOMAIN"
else
  DEFAULT_DOMAIN_NAME="$APP_ID.$DEFAULT_DOMAIN_FOR_SUBDOMAINS"
  if [ -n "$CLI_ID" ]; then
    DOMAIN_NAME="$DEFAULT_DOMAIN_NAME"
  else
    read -p "URL (Default: "${DEFAULT_DOMAIN_NAME}"): " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}
  fi
fi

echo " "

# Display the collected information
echo "App ID: $APP_ID"
echo "URL: https://$DOMAIN_NAME"

echo " "

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

# Create root directory for app
if sudo mkdir $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $APPS_DIRECTORY/$APP_ID"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $APPS_DIRECTORY/$APP_ID"
fi

# Change permissions for app directory to specified user
if sudo chown -R $USER $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Create a VirtualHost config file that points to the app's build directory
sudo touch /etc/apache2/sites-available/$DOMAIN_NAME.conf
if echo "<VirtualHost *:80>
    
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT

    DocumentRoot $APPS_DIRECTORY/$APP_ID/dist

    <Directory $APPS_DIRECTORY/$APP_ID/dist>
        AllowOverride all
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/$DOMAIN_NAME-error.log
    CustomLog /var/log/apache2/$DOMAIN_NAME-access.log combined
    
</VirtualHost>" | sudo tee /etc/apache2/sites-available/$DOMAIN_NAME.conf > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"
fi

# Enable site in Apache
if sudo a2ensite $DOMAIN_NAME > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Enabled site in Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot enable site in Apache"
fi

# Reload Apache
if sudo service apache2 reload; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Generate SSL certificate with Let's Encrypt
echo "Generating certificate with Let's Encrypt for $DOMAIN_NAME"
if sudo certbot --apache -d $DOMAIN_NAME,www.$DOMAIN_NAME; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Generated SSL certificate"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot generate SSL certificate"
fi

# Initialize Git repository
if git init --bare $REPOS_DIRECTORY/$APP_ID.git && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created bare git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create bare git repository"
fi

# Set up a hook that deploys any commits made to this repo 
sudo touch $REPOS_DIRECTORY/$APP_ID.git/hooks/post-receive
sudo chmod +x $REPOS_DIRECTORY/$APP_ID.git/hooks/post-receive
sudo chown $USER $REPOS_DIRECTORY/$APP_ID.git/hooks/post-receive

WORK_TREE="$APPS_DIRECTORY/$APP_ID"
GIT_DIR="$REPOS_DIRECTORY/$APP_ID.git"

if echo "#!/bin/bash

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"

cd "$APPS_DIRECTORY/$APP_ID" || { echo "Failed to change directory"; exit 1; }

echo "Updating code"
git --work-tree="$WORK_TREE" --git-dir="$GIT_DIR" checkout -f main
cd "$WORK_TREE" || exit

echo "Installing dependencies"
npm install --no-save || { echo "npm install failed"; exit 1; }

echo "Building app for production"
npm run build

echo -e \"${BOLD_GREEN}SUCCESS${END_COLOR} Deployed main to $APPS_DIRECTORY/$APP_ID\"
" | sudo tee $REPOS_DIRECTORY/$APP_ID.git/hooks/post-receive > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook"
fi

# Show confirmation messages
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD}*** $APP_ID is now set up! ***${END_COLOR}\n"
echo -e "* Visit ${BOLD}https://$DOMAIN_NAME${END_COLOR} to see the new site"
echo -e "\n* Add this remote and push to deploy: \n${BOLD}git remote add prod $USER@$SERVER:$REPOS_DIRECTORY/$APP_ID.git${END_COLOR}"
echo -e " "
