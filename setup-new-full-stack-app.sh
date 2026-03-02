#!/bin/bash

# Set up variables
SERVER="root.noshado.ws"
USER="leo"
ADMIN_CONTACT="www@noshado.ws"
APPS_DIRECTORY="/home/$USER/full-stack-apps"
DEFAULT_DOMAIN_FOR_SUBDOMAINS="leo.gd"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="/home/$USER/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Function to convert app name to hyphenated app ID
generate_app_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Parse CLI arguments
CLI_NAME="" CLI_ID="" CLI_DOMAIN="" CLI_ANTHROPIC="" CLI_ANTHROPIC_KEY=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) CLI_NAME="$2"; shift 2 ;;
    --id) CLI_ID="$2"; shift 2 ;;
    --domain) CLI_DOMAIN="$2"; shift 2 ;;
    --anthropic) CLI_ANTHROPIC="true"; shift ;;
    --anthropic-key) CLI_ANTHROPIC="true"; CLI_ANTHROPIC_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# App Name: use CLI arg or prompt
if [ -n "$CLI_NAME" ]; then
  APP_NAME="$CLI_NAME"
else
  read -p "App Name (Title Case): " APP_NAME
fi

# App ID: use CLI arg, auto-derive if name was given via CLI, or prompt
if [ -n "$CLI_ID" ]; then
  APP_ID="$CLI_ID"
else
  DEFAULT_APP_ID=$(generate_app_id "$APP_NAME")
  if [ -n "$CLI_NAME" ]; then
    APP_ID="$DEFAULT_APP_ID"
  else
    read -p "App ID (Default: "${DEFAULT_APP_ID}"): " APP_ID
    APP_ID=${APP_ID:-$DEFAULT_APP_ID}
  fi
fi

# Domain: use CLI arg, auto-derive if any CLI args were given, or prompt
if [ -n "$CLI_DOMAIN" ]; then
  DOMAIN_NAME="$CLI_DOMAIN"
else
  DEFAULT_DOMAIN_NAME="$APP_ID.$DEFAULT_DOMAIN_FOR_SUBDOMAINS"
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

echo " "

# Display the collected information
echo "App Name: $APP_NAME"
echo "App ID: $APP_ID"
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
if echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$APPS_DIRECTORY/$APP_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $APPS_DIRECTORY/$APP_ID"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $APPS_DIRECTORY/$APP_ID"
fi

# Change permissions for app directory to specified user
if echo "$SUDO_PASSWORD" | sudo -S chown -R "$USER" "$APPS_DIRECTORY/$APP_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to $USER"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to $USER"
fi

# Create src directory for app
if sudo mkdir $APPS_DIRECTORY/$APP_ID/src; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created src directory at $APPS_DIRECTORY/$APP_ID/src"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create src directory at $APPS_DIRECTORY/$APP_ID/src"
fi

# Create server.js
sudo touch $APPS_DIRECTORY/$APP_ID/server.js
SERVER_JS_EXTRA_IMPORTS=""
SERVER_JS_EXTRA_INIT=""
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
  SERVER_JS_EXTRA_IMPORTS='import '"'"'dotenv/config'"'"';
import Anthropic from "@anthropic-ai/sdk";
'
  SERVER_JS_EXTRA_INIT='
const anthropic = new Anthropic();
'
fi
if echo "${SERVER_JS_EXTRA_IMPORTS}"'import express from "express";
import Database from "better-sqlite3";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = '"$PORT"';'"${SERVER_JS_EXTRA_INIT}"'

// SQLite setup
const db = new Database(join(__dirname, "data.sqlite"));
db.pragma("journal_mode = WAL");

app.use(express.json());

// Serve static files from dist
app.use(express.static(join(__dirname, "dist")));

// API endpoint for SQLite queries
app.post("/api/query", (req, res) => {
  try {
    const { sql, params = [] } = req.body;
    const stmt = db.prepare(sql);
    if (stmt.reader) {
      const rows = stmt.all(...params);
      res.json({ rows });
    } else {
      const result = stmt.run(...params);
      res.json({ result });
    }
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// SPA fallback
app.get("*", (req, res) => {
  res.sendFile(join(__dirname, "dist", "index.html"));
});

app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
' | sudo tee $APPS_DIRECTORY/$APP_ID/server.js > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created server.js file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create server.js file"
fi

# Create .env file if Anthropic is enabled
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
    sudo touch $APPS_DIRECTORY/$APP_ID/.env
    if echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY" | sudo tee $APPS_DIRECTORY/$APP_ID/.env > /dev/null; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created .env file with Anthropic API key"
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create .env file"
    fi
fi

# Create a basic src/App.jsx file
sudo touch $APPS_DIRECTORY/$APP_ID/src/App.jsx
if echo "import React from \"react\";
import styled from \"styled-components\";

const Page = styled.div\`
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  font-size: 24px;
  color: #333;
\`;

function App() {
  return <Page>Hello world!</Page>;
}

export default App;
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/App.jsx > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/App.jsx file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/App.jsx file"
fi

# Create a basic src/index.css
sudo touch $APPS_DIRECTORY/$APP_ID/src/index.css
if echo "body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", \"Roboto\", \"Oxygen\",
    \"Ubuntu\", \"Cantarell\", \"Fira Sans\", \"Droid Sans\", \"Helvetica Neue\",
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, \"Courier New\",
    monospace;
}
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/index.css > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/index.css file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/index.css file"
fi

# Create a basic src/main.jsx
sudo touch $APPS_DIRECTORY/$APP_ID/src/main.jsx
if echo "import React from \"react\";
import ReactDOM from \"react-dom/client\";
import \"./index.css\";
import App from \"./App\";

const root = ReactDOM.createRoot(document.getElementById(\"root\"));
root.render(<App />);
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/main.jsx > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/main.jsx file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/main.jsx file"
fi

# Create a basic index.html
sudo touch $APPS_DIRECTORY/$APP_ID/index.html
if echo "<!DOCTYPE html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>$APP_NAME</title>
  </head>
  <body>
    <div id=\"root\"></div>
    <script type=\"module\" src=\"/src/main.jsx\"></script>
  </body>
</html>
" | sudo tee $APPS_DIRECTORY/$APP_ID/index.html > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic index.html file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic index.html file"
fi

# Create vite.config.js
sudo touch $APPS_DIRECTORY/$APP_ID/vite.config.js
if echo "import { defineConfig } from \"vite\";
import react from \"@vitejs/plugin-react\";

export default defineConfig({
  plugins: [react()],
});
" | sudo tee $APPS_DIRECTORY/$APP_ID/vite.config.js > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created vite.config.js file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create vite.config.js file"
fi

# Create basic package.json file
ANTHROPIC_DEPS=""
if [ "$ENABLE_ANTHROPIC" = "true" ]; then
  ANTHROPIC_DEPS='
    "@anthropic-ai/sdk": "^0.39.0",
    "dotenv": "^16.4.7",'
fi
sudo touch $APPS_DIRECTORY/$APP_ID/package.json
if echo "{
  \"name\": \"$APP_ID\",
  \"version\": \"0.1.0\",
  \"private\": true,
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite\",
    \"build\": \"vite build\",
    \"preview\": \"vite preview\",
    \"start\": \"node server.js\"
  },
  \"dependencies\": {$ANTHROPIC_DEPS
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\",
    \"styled-components\": \"^6.1.11\",
    \"express\": \"^4.19.2\",
    \"better-sqlite3\": \"^11.0.0\"
  },
  \"devDependencies\": {
    \"@vitejs/plugin-react\": \"^4.3.4\",
    \"vite\": \"^6.0.0\"
  }
}
" | sudo tee $APPS_DIRECTORY/$APP_ID/package.json > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic package.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic package.json file"
fi

# Create a setup-log.json
sudo touch $APPS_DIRECTORY/$APP_ID/setup-log.json
if echo "{
  \"app_id\": \"$APP_ID\",
  \"app_name\": \"$APP_NAME\",
  \"domain\": \"https://$DOMAIN_NAME\",
  \"host\": \"localhost\",
  \"port\": \"$PORT\",
  \"author\": \"$USER\",
  \"anthropic\": $ENABLE_ANTHROPIC,
  \"created_on\": \"$(date)\"
}" | sudo tee $APPS_DIRECTORY/$APP_ID/setup-log.json > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created setup-log.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create setup-log.json file"
fi

# Create basic gitignore file
sudo touch $APPS_DIRECTORY/$APP_ID/.gitignore
if echo 'node_modules/
dist/
.env
*.sqlite
' | sudo tee $APPS_DIRECTORY/$APP_ID/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Change permissions for app directory to specified user
if sudo chown -R $USER $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Install node modules
if cd $APPS_DIRECTORY/$APP_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Build app for production
if cd $APPS_DIRECTORY/$APP_ID && npm run build; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Built app for production"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot build app for production"
fi

# Append app to ecosystem.config.js
ECOSYSTEM_FILE="/home/$USER/ecosystem.config.js"
if node -e "
const fs = require('fs');
const config = require('$ECOSYSTEM_FILE');
config.apps.push({
  name: '$APP_ID',
  script: 'server.js',
  cwd: '$APPS_DIRECTORY/$APP_ID',
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
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Added $APP_ID to ecosystem.config.js"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot add $APP_ID to ecosystem.config.js"
fi

# Start node process via PM2
if pm2 start "$ECOSYSTEM_FILE" --only "$APP_ID" && pm2 save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Started $APP_ID via PM2"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot start $APP_ID via PM2"
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
if cd $APPS_DIRECTORY/$APP_ID && \
    git init && \
    git checkout -b main && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create git repository"
fi

# Commit basic code
if git add . && git commit -m "Adding basic template" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Committed initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot initial code to repository"
fi

# Change permissions for all files in app directory to specified user
if sudo chown -R $USER $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Set up a hook that deploys any commits made to this repo
sudo touch $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive
sudo chmod +x $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive
sudo chown $USER $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive

if echo '#!/bin/bash

# Load nvm so node/npm/pm2 are available in non-interactive shells
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd '"$APPS_DIRECTORY/$APP_ID"' || { echo "Failed to change directory"; exit 1; }

echo "Installing dependencies"
npm install --no-save || { echo "npm install failed"; exit 1; }

echo "Building app for production"
npm run build || { echo "Build failed"; exit 1; }

echo "Restarting via PM2"
# Kill any stale process on the port before restarting
STALE_PID=$(lsof -ti :'"$PORT"' -sTCP:LISTEN 2>/dev/null)
if [ -n "$STALE_PID" ]; then
  echo "Killing stale process on port '"$PORT"' (PID $STALE_PID)"
  kill -9 "$STALE_PID" 2>/dev/null
  sleep 1
fi
pm2 restart '"$APP_ID"'
pm2 save

echo -e "\e[1;32mSUCCESS\e[0m Deployed '"$APP_ID"'"' | sudo tee $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive > /dev/null; then
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
echo -e "\n* Clone this repository and push to origin to deploy: \n${BOLD}git clone $USER@$SERVER:$APPS_DIRECTORY/$APP_ID${END_COLOR}"
echo -e " "
