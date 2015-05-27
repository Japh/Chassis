require 'mina/git'
require './config/mina-local.rb'

non_destructive = ENV['soft']

backup_to = "#{deploy_to}/shared/backup"
time = Time.new
dest_file = "#{time.year}#{time.month}#{time.day}_#{time.hour}#{time.min}#{time.sec}"
src_file = ENV['file']

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .ruby-version or .rbenv-version to your repository.
  # invoke :'rbenv:load'

  queue %[echo "----> Loading environment"]
  queue %[PATH="#{php_path}:$PATH"]
  queue %[source #{home_dir}/.profile]

  # For those using RVM, use this to load an RVM version@gemset.
  # invoke :'rvm:use[ruby-1.9.3-p125@default]'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/log"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/backup"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/backup"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/config"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/uploads"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/uploads"]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'deploy:cleanup'

    in_directory "#{deploy_to}/public" do
      queue %[if [ -h #{deploy_to}/public/wp-content ]; then rm #{deploy_to}/public/wp-content; fi]
      queue %[ln -s #{deploy_to}/current #{deploy_to}/public/wp-content]
      queue %[echo "----> Update permalink structure"]
      queue %[wp rewrite structure "/%year%/%monthnum%/%day%/%postname%/"]
    end
  end
end

desc "Rollback to previous version."
task :rollback => :environment do
    queue %[echo  "----> Start to rollback"]
    queue %[if [ $(ls #{deploy_to}/releases | wc -l) -gt 1 ]; then echo "----> Relink to previous release" && unlink #{deploy_to}/current && ln -s #{deploy_to}/releases/"$(ls #{deploy_to}/release | tail -2 | head -1)" #{deploy_to}/current && echo "Remove old releases" && rm -rf #{deploy_to}/releases/"$(ls #{deploy_to}/releases | tail -1)" && echo "$(ls #{deploy_to}/releases | tail -1)" > #{deploy_to}/last_version && echo "Done. Rollback to v$(cat #{deploy_to}/last_version)" ; else echo "No more releases to rollback to" ; fi]
end

desc "Show current WordPress version."
task :wp_version => :environment do
    queue %[echo "----> #{hostname} is running WordPress:"]
    queue "cd #{deploy_to}/public && wp core version"
    #puts `echo "Hello world!"`
end

desc "Dump production database."
task :db_dump => :environment do
    queue %[[ -d #{backup_to} ] || mkdir -p #{backup_to}]

    in_directory "#{deploy_to}/public" do
        queue %[echo "----> Exporting database to #{dest_file}.sql.gz"]
        queue %[wp db export - | gzip > #{backup_to}/#{dest_file}.sql.gz]
    end
end

desc "Pull database export from production (Requires: file=<file>)"
task :pull_db do
    if src_file then
        puts `echo "----> Downloading backup #{src_file}.sql.gz to ./db-sync/"`
        puts `scp #{user}@#{domain}:#{backup_to}/#{src_file}.sql.gz ./db-sync/`
        puts `echo "----> Decompressing file"`
        puts `gunzip ./db-sync/#{src_file}.sql.gz`
        puts `echo "----> Removing file from server"`
        unless non_destructive then
            queue %[rm #{backup_to}/#{src_file}.sql.gz]
        end
    else
        puts `echo "No source file specified"`
    end
end

desc "Import production database to development (Requires: file=<file>)"
task :import_db2dev do
    if src_file then
        puts `echo "----> Importing #{src_file}.sql database"`
        puts `vagrant ssh -c "cd /vagrant/; wp db import ./db-sync/#{src_file}.sql"`
        puts `echo "----> Search and replacing #{hostname} with #{dev}"`
        puts `vagrant ssh -c "cd /vagrant/; wp search-replace #{hostname} #{dev}"`
        puts `echo "----> Cleaning up file"`
        unless non_destructive then
            puts `rm ./db-sync/#{src_file}.sql`
        end
    else
        puts `echo "No source file specified"`
    end
end

desc "Pull uploads from production."
task :pull_uploads do
    puts `echo "----> Downloading uploads from production"`
    puts `rsync -r #{user}@#{domain}:#{deploy_to}/#{shared_path}/uploads/ ./content/uploads/`
end

desc "Export development database"
task :export_db do
    puts `echo "----> Search and replacing #{dev} with #{hostname}"`
    puts `vagrant ssh -c "cd /vagrant/; wp search-replace #{dev} #{hostname}"`
    puts `echo "----> Exporting #{dest_file}.sql.gz database"`
    puts `vagrant ssh -c "cd /vagrant/; wp db export - | gzip > ./db-sync/#{dest_file}.sql.gz"`
    puts `echo "----> Resetting #{hostname} with #{dev}"`
    puts `vagrant ssh -c "cd /vagrant/; wp search-replace #{hostname} #{dev}"`
end

desc "Push database export to production (Requires: file=<file>)"
task :push_db do
    if src_file then
        puts `echo "----> Uploading backup #{src_file}.sql.gz to #{hostname}:#{backup_to}/"`
        puts `scp ./db-sync/#{src_file}.sql.gz #{user}@#{domain}:#{backup_to}/`
        unless non_destructive then
            puts `echo "----> Removing file from directory"`
            puts `rm ./db-sync/#{src_file}.sql.gz`
        end
    else
        puts `echo "No source file specified"`
    end
end

desc "Import development database (Requires: file=<file>)"
task :import_db2prod => :environment do
    in_directory "#{deploy_to}/public" do
        queue %[echo "----> Decompressing database export #{src_file}.sql.gz"]
        queue %[gunzip #{backup_to}/#{src_file}.sql.gz]
        queue %[echo "----> Importing #{backup_to}/#{src_file}.sql to database"]
        queue %[wp db import #{backup_to}/#{src_file}.sql]
        unless non_destructive then
            queue %[echo "----> Removing file from server"]
            queue %[rm #{backup_to}/#{src_file}.sql]
        end
    end
end

desc "Migrate production data to development environment"
task :migrate_prod2dev => :environment do
    puts `mina db_dump && mina pull_db file=#{dest_file} && mina import_db2dev file=#{dest_file} && mina pull_uploads`
end

desc "Migrate development data to production environment"
task :migrate_dev2prod => :environment do
    puts `mina export_db && mina push_db file=#{dest_file} && mina import_db2prod file=#{dest_file}`
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers
