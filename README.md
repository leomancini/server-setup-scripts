# Server Setup Scripts

## [host-manager.sh](https://github.com/leomancini/server-setup-scripts/blob/main/host-manager.sh)
#### Interactive menu for managing all services, apps, and domains

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
#### Setup an Express server accessible from an Apache VirtualHost subdomain, managed by PM2

1. Find an available port
2. Create root directory for service
3. Change permissions for service directory to specified user
4. Create a basic server
5. Create a basic README.md
6. Create basic package.json file
7. Install node modules
8. Add service to PM2 ecosystem config
9. Start service via PM2
10. Create a VirtualHost config file that proxies requests to node
11. Enable site in Apache
12. Reload Apache
13. Generate SSL certificate with Let's Encrypt
14. Initialize Git repository
15. Create basic gitignore file
16. Commit basic code
17. Set up a post-receive hook that restarts the service via PM2 on push

## [restart-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/restart-express-server.sh)
#### Restart an Express server created by [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-express-server.sh)

1. Install node modules
2. Restart service via PM2
3. Reload Apache

## [remove-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/remove-express-server.sh)
#### Decommission an Express server created by [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-express-server.sh)

1. Disable site in Apache
2. Delete Apache config files
3. Delete service directory
4. Remove service from PM2
5. Remove service from PM2 ecosystem config
6. Reload Apache

## [setup-new-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-react-app.sh)
#### Setup a React app accessible from an Apache VirtualHost domain or subdomain

1. Create root directory for app
2. Create src directory for app
3. Create public directory for app
4. Create basic files in src/
5. Create basic files in public/
6. Create a basic README.md
7. Create a basic package.json
8. Create a setup-log.json
9. Change permissions for app directory to specified user
10. Install node modules
11. Build app for production
12. Create a VirtualHost config file that points to the app's build directory
13. Enable site in Apache
14. Reload Apache
15. Generate SSL certificate with Let's Encrypt
16. Initialize Git repository
17. Create basic gitignore file
18. Commit basic code
19. Set up a hook that deploys any commits made to this repo

## [upload-existing-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/upload-existing-react-app.sh)
#### Upload and deploy an existing React app from a local or remote repository

## [rebuild-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/rebuild-react-app.sh)
#### Rebuild a React app created by [setup-new-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-react-app.sh)

1. Install node modules
2. Build app for production
3. Reload Apache

## [remove-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/remove-react-app.sh)
#### Decommission a React app created by [setup-new-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/setup-new-react-app.sh)

1. Disable site in Apache
2. Delete Apache config file
3. Delete app directory
4. Reload Apache

## [remove-uploaded-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/remove-uploaded-react-app.sh)
#### Decommission a React app uploaded by [upload-existing-react-app.sh](https://github.com/leomancini/server-setup-scripts/blob/main/upload-existing-react-app.sh)
