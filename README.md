# Server Setup Scripts

## [setup-new-domain.sh](https://github.com/leomancini/server-setup-scripts/blob/master/setup-new-domain.sh)
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

## [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/master/setup-new-express-server.sh)
#### Setup an Express server accessible from a Apache VirtualHost subdomain

1. Find an available port
2. Create root directory for domain
3. Change permissions for domain directory to specified user
4. Create a basic server
5. Create basic package.json file
6. Install node modules
7. Start node process
8. Create a VirtualHost config file that proxies requests to node
9. Enable site in Apache
10. Reload Apache
11. Generate SSL certificate with Let's Encrypt
12. Initialize Git repository
13. Create basic gitignore file
14. Commit basic code
15. Set up a hook that deploys any commits made to this repo

## [remove-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/master/remove-express-server.sh)
#### Decommission an Express server created by [setup-new-express-server.sh](https://github.com/leomancini/server-setup-scripts/blob/master/setup-new-express-server.sh)

1. Disable site in Apache
2. Delete Apache config file
3. Delete site directory
4. Stop node process
5. Reload Apache
