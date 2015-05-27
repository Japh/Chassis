set :hostname, "yourdomain.com"                                  # The publicly accessible domain name for your production site.
set :domain, "server_ip_address"                                 # The IP address for your server that you can connect to over SSH.
set :dev, "vagrant.local"                                        # The host name for your local environment, vagrant.local is the Chassis default.
set :home_dir, "/var/www/"                                       # Home directory on your production server for the SSH user you'll be connecting with.
set :deploy_to, "#{home_dir}/wordpress"                          # The webroot of your site on the production server.
set :repository, "git@github.com:Username/your-project-repo.git" # Your project's Git repository that you will deploy from.
set :branch, "master"                                            # The Git branch you will use for production.
set :php_path, "/usr/bin"                                        # Path to the directory where the PHP binary is on your production server.

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ["uploads"] # Add any others you also need.

# Optional settings:
set :user, "username"    # Username in the server to SSH to.
set :port, "22"          # SSH port number.
set :forward_agent, true # Forward SSH agent.
