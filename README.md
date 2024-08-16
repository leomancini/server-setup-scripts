# Server Setup Scripts

## [setup-new-domain.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-domain.sh)
#### Setup an Apache VirtualHost for a domain or subdomain serving PHP or HTML

1. Create root directory for domain
2. Create public html directory
3. Change permissions for domain directory to specified user
4. If an index.html file doesn't exist, create a placeholder one
5. Optional: Pick PHP version
6. Create a VirtualHost config file that points to the domain directory
7. Reload Apache
8. Optional: Generate SSL certificate from Let's Encrypt
9. If Git, set up a hook that deploys any commits made to this repo 
10. Optional: Set up a bare Git repository in the domain directory

## [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-express-server.sh)
#### Setup an Express server accessible from a Apache VirtualHost subdomain

1. Find an available port
2. Create root directory for domain
3. Change permissions for domain directory to specified user
4. Create a basic server
5. Create a basic README.md
6. Create basic package.json file
7. Install node modules
8. Start node process
9. Create a VirtualHost config file that proxies requests to node
10. Enable site in Apache
11. Reload Apache
12. Generate SSL certificate with Let's Encrypt
13. Initialize Git repository
14. Create basic gitignore file
15. Commit basic code
16. Set up a hook that deploys any commits made to this repo

## [remove-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/remove-express-server.sh)
#### Decommission an Express server created by [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-express-server.sh)

1. Disable site in Apache
2. Delete Apache config file
3. Delete site directory
4. Stop node process
5. Reload Apache

## [setup-new-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-react-app.sh)
#### Setup a React app accessible from a Apache VirtualHost domain or subdomain

1. Create root directory for app
2. Create src directory for app
3. Create public directory for app
4. Creates basic files in src/
4. Creates basic files in public/
5. Create a basic README.md
6. Create a basic package.json
7. Create a setup-log.json
8. Change permissions for app directory to specified user
9. Install node modules
10. Build app for production
11. Create a VirtualHost config file that points to the app's build directory
12. Enable site in Apache
13. Reload Apache
14. Generate SSL certificate with Let's Encrypt
15. Initialize Git repository
16. Create basic gitignore file
17. Commit basic code
18. Set up a hook that deploys any commits made to this repo 

    
## [remove-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/remove-react-app.sh)
#### Decommission a React app created by [setup-new-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-react-app.sh)

1. Disable site in Apache
2. Delete Apache config file
3. Delete app directory
5. Reload Apache
