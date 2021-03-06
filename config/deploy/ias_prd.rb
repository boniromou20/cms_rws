# Define your release to be deployed to integration environment here.
# Release number for integration environment is supposed to be odd numbers.
set :branch, 'REL_1_2_3'

# Define your repository server for integration environment here.
#   production SVN - svn.prod.laxigames.com
#   development SVN - svn.mo.laxino.com
set :user, "ias"
set :group, "ias_rnd"
set :repo_host, 'svn.mo.laxino.com'

# Define your application servers for integration environment here.
#   int - Integration
#   stg - Staging
#   prd - Production
role :app, 'do-prd-generic-app01.idc.local'

role :cronjob_app, 'do-prd-generic-app01.idc.local'

# Define your database servers for integration environment here.
# role :db,  "int-cons-db01.rnd.laxino.com", :primary => true

# Define your application cluster with Nginx settings here
# These variables will be used in generating Nginx/Thin config files
set :nginx_worker_processes, 2
set :cluster_port, 10060
set :virtual_server_name, 'do-prd-cms-vapp01.idc.local'
set :num_of_servers, 12
