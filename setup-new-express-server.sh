#!/bin/bash

# Set up variables for server IP, user, and domains directory
SERVER="[INSERT_SERVER_IP]"
USER="[INSERT_USERNAME]"
DOMAINS_DIRECTORY="/home/$USER/domains"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

read -p "Service Name: " SERVICE_NAME
read -p "URL: $SERVICE_NAME." DOMAIN_NAME

SERVICE_AND_DOMAIN="${SERVICE_NAME}.${DOMAIN_NAME}"

echo -e " "

echo "Service will be available at https://$SERVICE_AND_DOMAIN:80"

# Find an available port
find_available_port() {
    local port=3100  # Start with a default port
    while netstat -tna | grep -q :$port; do
        port=$((port+1))
    done
    echo $port
}

PORT=$(find_available_port)
echo "Service will be running on localhost:$PORT"

echo -e " "

# Create root directory for domain
if sudo mkdir $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN"
fi

# Change permissions for domain directory to specified user
if sudo chown -R $USER $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to $USER"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to $USER"
fi

# Create a basic server
sudo touch $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/server.js
if echo "import express from 'express';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = $PORT;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.send('Hello, World!');
});

app.listen(port, () => {
  console.log('Server is running');
});
" | sudo tee $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/server.js > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic server file"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic server file"
fi

# Create basic package.json file
sudo touch $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/package.json
if echo '{
  "name": "'"$SERVICE_AND_DOMAIN"'",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node '"$SERVICES_DIRECTORY"'/'"$SERVICE_AND_DOMAIN"'/server.js"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {
    "express": "^4.19.2",
    "path": "^0.12.7",
    "url": "^0.11.3"
  }
}
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/package.json > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic package.json file"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic package.json file"
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN && npm install; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules for $SERVICE_AND_DOMAIN"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules for $SERVICE_AND_DOMAIN"
fi

# Start node process
if cd $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN && nohup npm run start > ./output.log 2>&1 & then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Started node with process ID $!"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot start node"
fi

# Create a VirtualHost config file that points to the domain directory
sudo touch /etc/apache2/sites-available/$SERVICE_AND_DOMAIN.conf
if echo "<VirtualHost *:80>
	
    ServerName $SERVICE_AND_DOMAIN
    ServerAlias www.$SERVICE_AND_DOMAIN
    ServerAdmin www@noshado.ws

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full
    <Proxy *>
        Require all granted
    </Proxy>
    ProxyPass / http://127.0.0.1:$PORT/
    ProxyPassReverse / http://127.0.0.1:$PORT/

    ErrorLog /var/log/apache2/$SERVICE_AND_DOMAIN-error.log
    CustomLog /var/log/apache2/$SERVICE_AND_DOMAIN-access.log combined
	
</VirtualHost>" | sudo tee /etc/apache2/sites-available/$SERVICE_AND_DOMAIN.conf > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created Apache config file at /etc/apache2/sites-available/$SERVICE_AND_DOMAIN.conf"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create Apache config file at /etc/apache2/sites-available/$SERVICE_AND_DOMAIN.conf"
fi

# Enable site in Apache
if sudo a2ensite $SERVICE_AND_DOMAIN > /dev/null; then
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
echo "Generating certificate with Let's Encrypt for $SERVICE_AND_DOMAIN"
if sudo certbot --apache -d $SERVICE_AND_DOMAIN,www.$SERVICE_AND_DOMAIN; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Generated SSL certificate"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot generate SSL certificate"
fi

# Initialize Git repository
if cd $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN && \
    git init && \
    git checkout -b main && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create git repository"
fi

# Create basic gitignore file
sudo touch $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.gitignore
if echo '.env
node_modules/
output.log
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Commit basic code
if git add . && git commit -m "first commit" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Commited initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot initial code to repository"
fi

# Set up a hook that deploys any commits made to this repo 
sudo touch $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.git/hooks/post-receive
sudo chmod +x $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.git/hooks/post-receive
sudo chown $USER $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.git/hooks/post-receive

if echo "#!/bin/bash

cd "$SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN" || { echo "Failed to change directory"; exit 1; }

echo "Installing dependencies"
npm install || { echo "npm install failed"; exit 1; }

echo "Stopping existing process"
pkill -f "node.*$SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN" > /dev/null 2>&1 || true

echo "Starting new process"
nohup npm run start > ./output.log 2>&1 &

sleep 2
if pgrep -f "node.*$SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN" > /dev/null; then
    echo -e \"${BOLD_GREEN}SUCCESS${END_COLOR} Deployed main to $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN\"
else
    echo "Failed to start the process"
    exit 1
fi" | sudo tee $SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN/.git/hooks/post-receive > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"

echo -e "${BOLD}*** $SERVICE_AND_DOMAIN is now set up! ***${END_COLOR}\n"

echo -e "* Visit ${BOLD}https://$SERVICE_AND_DOMAIN${END_COLOR} to see the new site"

echo -e "\n* Clone this repository and push to origin to deploy: \n${BOLD}git clone $USER@$SERVER:$SERVICES_DIRECTORY/$SERVICE_AND_DOMAIN${END_COLOR}"

echo -e " "
