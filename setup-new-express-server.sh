#!/bin/bash

# Set up variables
SERVER="root.noshado.ws"
USER="leo"
ADMIN_CONTACT="www@noshado.ws"
SERVICES_DIRECTORY="/home/$USER/services"
DEFAULT_DOMAIN_FOR_SUBDOMAINS="noshado.ws"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="/home/$USER/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Function to convert service name to hyphenated service ID
generate_service_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Parse CLI arguments
CLI_NAME="" CLI_ID="" CLI_DOMAIN="" CLI_ANTHROPIC="" CLI_ANTHROPIC_KEY="" CLI_PRIVATE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) CLI_NAME="$2"; shift 2 ;;
    --id) CLI_ID="$2"; shift 2 ;;
    --domain) CLI_DOMAIN="$2"; shift 2 ;;
    --anthropic) CLI_ANTHROPIC="true"; shift ;;
    --anthropic-key) CLI_ANTHROPIC="true"; CLI_ANTHROPIC_KEY="$2"; shift 2 ;;
    --private) CLI_PRIVATE="true"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Service Name: use CLI arg or prompt
if [ -n "$CLI_NAME" ]; then
  SERVICE_NAME="$CLI_NAME"
else
  read -p "Service Name (Title Case): " SERVICE_NAME
fi

# Service ID: use CLI arg, auto-derive if name was given via CLI, or prompt
if [ -n "$CLI_ID" ]; then
  SERVICE_ID="$CLI_ID"
else
  DEFAULT_SERVICE_ID=$(generate_service_id "$SERVICE_NAME")
  if [ -n "$CLI_NAME" ]; then
    SERVICE_ID="$DEFAULT_SERVICE_ID"
  else
    read -p "Service ID (Default: "${DEFAULT_SERVICE_ID}"): " SERVICE_ID
    SERVICE_ID=${SERVICE_ID:-$DEFAULT_SERVICE_ID}
  fi
fi

# Domain: use CLI arg, auto-derive if any CLI args were given, or prompt
if [ -n "$CLI_DOMAIN" ]; then
  DOMAIN_NAME="$CLI_DOMAIN"
else
  DEFAULT_DOMAIN_NAME="$SERVICE_ID.$DEFAULT_DOMAIN_FOR_SUBDOMAINS"
  if [ -n "$CLI_NAME" ] || [ -n "$CLI_ID" ]; then
    DOMAIN_NAME="$DEFAULT_DOMAIN_NAME"
  else
    read -p "URL (Default: "${DEFAULT_DOMAIN_NAME}"): " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}
  fi
fi

# Anthropic API: use CLI flag or prompt
if [ -n "$CLI_ANTHROPIC" ]; then
  ENABLE_ANTHROPIC="true"
else
  if [ -n "$CLI_NAME" ] || [ -n "$CLI_ID" ]; then
    ENABLE_ANTHROPIC="false"
  else
    read -p "Enable Anthropic API access? (y/n): " ANTHROPIC_ANSWER
    if [[ "$ANTHROPIC_ANSWER" =~ ^[Yy] ]]; then
      ENABLE_ANTHROPIC="true"
    else
      ENABLE_ANTHROPIC="false"
    fi
  fi
fi

# Anthropic API key: use CLI arg > env var > interactive prompt
ANTHROPIC_KEY=""
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
  if [ -n "$CLI_ANTHROPIC_KEY" ]; then
    ANTHROPIC_KEY="$CLI_ANTHROPIC_KEY"
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    ANTHROPIC_KEY="$ANTHROPIC_API_KEY"
  else
    read -s -p "Enter Anthropic API key: " ANTHROPIC_KEY
    echo
  fi
fi

# GitHub repo visibility: use CLI flag or prompt
if [ -n "$CLI_PRIVATE" ]; then
  GITHUB_PRIVATE="true"
else
  if [ -n "$CLI_NAME" ] || [ -n "$CLI_ID" ]; then
    GITHUB_PRIVATE="false"
  else
    read -p "Make GitHub repo private? (y/n, Default: n): " PRIVATE_ANSWER
    if [[ "$PRIVATE_ANSWER" =~ ^[Yy] ]]; then
      GITHUB_PRIVATE="true"
    else
      GITHUB_PRIVATE="false"
    fi
  fi
fi

echo " "

# Display the collected information
echo "Service Name: $SERVICE_NAME"
echo "Service ID: $SERVICE_ID"
echo "URL: https://$DOMAIN_NAME"

# Find an available port
find_available_port() {
    local port=3100  # Start with a default port
    while netstat -tna | grep -q :$port; do
        port=$((port+1))
    done
    echo $port
}

PORT=$(find_available_port)
echo "Host: localhost:$PORT"

echo " "



echo " "





# Create root directory for service
if sudo mkdir -p "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $SERVICES_DIRECTORY/$SERVICE_ID"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $SERVICES_DIRECTORY/$SERVICE_ID"
fi

# Change permissions for services directory to specified user
if sudo chown -R "$USER" "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to $USER"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to $USER"
fi

# Create a setup-log.json
sudo touch "$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json"
if echo "{
  \"service_id\": \"$SERVICE_ID\",
  \"service_name\": \"$SERVICE_NAME\",
  \"domain\": \"https://$DOMAIN_NAME\",
  \"host\": \"localhost\",
  \"port\": \"$PORT\",
  \"author\": \"$USER\",
  \"anthropic\": $ENABLE_ANTHROPIC,
  \"created_on\": \"$(date)\"
}" | sudo tee "$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created setup-log.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create setup-log.json file"
fi

# Create a basic server
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/server.js
SERVER_JS_IMPORTS="import express from 'express';"
SERVER_JS_INIT=""
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
  SERVER_JS_IMPORTS="import 'dotenv/config';
import Anthropic from '@anthropic-ai/sdk';
import express from 'express';"
  SERVER_JS_INIT="
const anthropic = new Anthropic();
"
fi
if echo "$SERVER_JS_IMPORTS

const app = express();
const port = $PORT;
$SERVER_JS_INIT
app.get('/', (req, res) => {
  res.send('Hello world!');
});

app.listen(port, () => {
  console.log(\`Server is running at http://localhost:\${port}\`);
});
" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/server.js > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic server file"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic server file"
fi

# Create .env file if Anthropic is enabled
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
    sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.env
    if echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.env > /dev/null; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created .env file with Anthropic API key"
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create .env file"
    fi
fi

# Create a basic README.md
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/README.md
if echo "# $SERVICE_NAME

Identifier: $SERVICE_ID

Created: $(date)" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/README.md > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic README.md file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic README.md file"
fi

# Create basic package.json file
ANTHROPIC_DEPS=""
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
  ANTHROPIC_DEPS='
    "@anthropic-ai/sdk": "^0.39.0",
    "dotenv": "^16.4.7",'
fi
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/package.json
if echo '{
  "name": "'"$SERVICE_ID"'",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node '"$SERVICES_DIRECTORY"'/'"$SERVICE_ID"'/server.js",
    "dev": "nodemon server.js"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {'"$ANTHROPIC_DEPS"'
    "express": "^4.19.2",
    "path": "^0.12.7",
    "url": "^0.11.3"
  }
}
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/package.json > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic package.json file"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic package.json file"
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Append service to ecosystem.config.js
ECOSYSTEM_FILE="/home/$USER/ecosystem.config.js"
if node -e "
const fs = require('fs');
const config = require('$ECOSYSTEM_FILE');
config.apps.push({
  name: '$SERVICE_ID',
  script: 'server.js',
  cwd: '$SERVICES_DIRECTORY/$SERVICE_ID',
  autorestart: true,
  watch: false,
  log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
});
const lines = config.apps.map(app => {
  const entries = Object.entries(app).map(([k, v]) => '      ' + k + ': ' + JSON.stringify(v) + ',');
  return '    {\n' + entries.join('\n') + '\n    }';
});
fs.writeFileSync('$ECOSYSTEM_FILE', 'module.exports = {\n  apps: [\n' + lines.join(',\n') + ',\n  ],\n};\n');
"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Added $SERVICE_ID to ecosystem.config.js"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot add $SERVICE_ID to ecosystem.config.js"
fi

# Start node process via PM2
if pm2 start "$ECOSYSTEM_FILE" --only "$SERVICE_ID" && pm2 save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Started $SERVICE_ID via PM2"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot start $SERVICE_ID via PM2"
fi

# Create a VirtualHost config file that proxies requests to node
sudo touch /etc/apache2/sites-available/$DOMAIN_NAME.conf
if echo "<VirtualHost *:80>
	
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full
    <Proxy *>
        Require all granted
    </Proxy>
    ProxyPass / http://127.0.0.1:$PORT/
    ProxyPassReverse / http://127.0.0.1:$PORT/

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
if cd $SERVICES_DIRECTORY/$SERVICE_ID && \
    git init && \
    git checkout -b main && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create git repository"
fi

# Create basic gitignore file
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.gitignore
if echo '.env
.DS_Store
node_modules/
output.log
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Commit basic code
if git add . && git commit -m "Adding basic template" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Committed initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot initial code to repository"
fi

# Change permissions for all files in service directory to specified user
if sudo chown -R $USER $SERVICES_DIRECTORY/$SERVICE_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Set up a hook that deploys any commits made to this repo 
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive
sudo chmod +x $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive
sudo chown $USER $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive

if echo '#!/bin/bash

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd '"$SERVICES_DIRECTORY/$SERVICE_ID"' || { echo "Failed to change directory"; exit 1; }

echo "Installing dependencies"
npm install --no-save || { echo "npm install failed"; exit 1; }

# Build if a build script exists
if node -e "const p=require('"'"'./package.json'"'"'); process.exit(p.scripts && p.scripts.build ? 0 : 1)" 2>/dev/null; then
  echo "Building"
  npm run build || { echo "Build failed"; exit 1; }
fi

echo "Restarting via PM2"
pm2 stop '"$SERVICE_ID"' >/dev/null 2>&1
# Kill any stale process on the port before starting
STALE_PID=$(lsof -ti :'"$PORT"' -sTCP:LISTEN 2>/dev/null)
if [ -n "$STALE_PID" ]; then
  echo "Killing stale process on port '"$PORT"' (PID $STALE_PID)"
  kill -9 "$STALE_PID" 2>/dev/null
  sleep 1
fi
pm2 start '"$SERVICE_ID"' >/dev/null 2>&1
pm2 save >/dev/null 2>&1

echo -e "\e[1;32mSUCCESS\e[0m Deployed '"$SERVICE_ID"'"' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook"
fi

# Set up GitHub repository
GITHUB_USER="leomancini"
DEPLOY_KEY_PATH="${DREAMCOMPUTE_DEPLOY_KEY_PATH:-$HOME/.ssh/github_deploy_key}"

if [ "$GITHUB_PRIVATE" = "true" ]; then
  VISIBILITY="--private"
else
  VISIBILITY="--public"
fi

# Create deploy workflow
mkdir -p $SERVICES_DIRECTORY/$SERVICE_ID/.github/workflows
cat > $SERVICES_DIRECTORY/$SERVICE_ID/.github/workflows/deploy.yml << 'WORKFLOW_EOF'
name: Deploy to dreamcompute-leo

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Set up SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DREAMCOMPUTE_DEPLOY_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan root.noshado.ws >> ~/.ssh/known_hosts

      - name: Deploy
        run: |
          git remote add dreamcompute-leo leo@root.noshado.ws:REMOTE_PATH
          git push dreamcompute-leo main
WORKFLOW_EOF

# Replace REMOTE_PATH placeholder with actual path
sed -i "s|REMOTE_PATH|$SERVICES_DIRECTORY/$SERVICE_ID|g" $SERVICES_DIRECTORY/$SERVICE_ID/.github/workflows/deploy.yml

# Commit the workflow
cd $SERVICES_DIRECTORY/$SERVICE_ID
git add .github/
git commit -m "Add GitHub Actions deploy workflow" > /dev/null

# Create GitHub repo and push
if gh repo create "$GITHUB_USER/$SERVICE_ID" $VISIBILITY; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created GitHub repo at github.com/$GITHUB_USER/$SERVICE_ID"
    git remote add origin "git@github.com:$GITHUB_USER/$SERVICE_ID.git"
    git push -u origin main
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create GitHub repo"
fi

# Set deploy key secret
if [ -f "$DEPLOY_KEY_PATH" ]; then
    if gh secret set DREAMCOMPUTE_DEPLOY_KEY --repo "$GITHUB_USER/$SERVICE_ID" < "$DEPLOY_KEY_PATH"; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Set DREAMCOMPUTE_DEPLOY_KEY secret"
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot set deploy key secret"
    fi
else
    echo -e "${BOLD_RED}WARNING${END_COLOR} Deploy key not found at $DEPLOY_KEY_PATH"
    echo "  Set DREAMCOMPUTE_DEPLOY_KEY_PATH env var or place key at ~/.ssh/github_deploy_key"
    echo "  Then run: gh secret set DREAMCOMPUTE_DEPLOY_KEY --repo $GITHUB_USER/$SERVICE_ID < \$KEY_PATH"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD}*** $SERVICE_ID is now set up! ***${END_COLOR}\n"
echo -e "* Visit ${BOLD}https://$DOMAIN_NAME${END_COLOR} to see the new site"
echo -e "\n* Clone from GitHub and push to deploy:"
echo -e "${BOLD}git clone git@github.com:$GITHUB_USER/$SERVICE_ID.git${END_COLOR}"
echo -e " "
