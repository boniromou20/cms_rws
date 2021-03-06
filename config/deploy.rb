set :stages, %w(integration0 staging0 staging1 production0 sandbox0 sandbox2 smartocean2 mockup0 sandbox3 production3 sandbox ias_prd sandbox5)
set :default_stage, 'integration0'
require 'capistrano/ext/multistage'
require 'lax-capistrano-recipes/rws'
require 'bundler/capistrano'

set :app_server, "thin"
set :application, "cms_rws"
set :project, "rothorn"
set :env_path, "/opt/deploy/env/#{application}"
set :envrc_script, "#{env_path}/.envrc"

set :third_party_home, '/opt/third-party'
set :monit_home, "#{third_party_home}/monit"
set :monit, "#{monit_home}/bin/monit"
set :monit_conf, "#{monit_home}/conf/monitrc"
set :template_home, "/opt/deploy/lib/templates"
set :config_templates, "#{template_home}/config_with_bundle"
set :script_templates, "#{template_home}/script"
set :nginx, "#{third_party_home}/nginx/sbin/nginx"
set :crontab, '/usr/bin/crontab'
set :bundle_cmd, "source #{envrc_script}; bundle"
# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion
set :scm, "git"

set :user, "laxino"
#set :user, "guang.su"
set :group, "laxino_rnd"

# Define who should recieve alerts from Monit
set :alert_recipients, ['dennis.chio@laxino.com']

# Before you can execute sudo comands on the app server,
# please comment out the following line in the /etc/sudoers
#     Defaults    requiretty
set :use_sudo, false

# Define deployment destination and source,
# using lazy evaluation of variables
set(:deploy_to) { "#{env_path}/app_#{stage}" }
set(:repository) { "ssh://laxino@#{repo_host}/opt/laxino/stash_repos/#{project.sub('.', '/')}/#{application}.git" }

# Define your cron jobs here
set(:cronjobs) {
  ["0,30 * * * * #{deploy_to}/current/cronjob/clean_expired_token.sh #{stage} >> #{deploy_to}/current/log/clean_expired_token_#{stage}.log 2>&1", 
   "0 * * * * #{deploy_to}/current/cronjob/roll_shift.sh #{stage} >> #{deploy_to}/current/log/roll_shift_#{stage}.log 2>&1",
#   "* * * * * #{deploy_to}/current/cronjob/approve_transaction.sh  #{stage} >> #{deploy_to}/current/log/approve_transaction_#{stage}.log 2>&1",
   "*/5 * * * * #{deploy_to}/current/cronjob/update_player.sh #{stage} >> #{deploy_to}/current/log/update_player_#{stage}.log 2>&1",
   "* * * * * #{deploy_to}/current/cronjob/add_shift_id.sh #{stage} >> #{deploy_to}/current/log/add_shift_id_#{stage}.log 2>&1"]
}
