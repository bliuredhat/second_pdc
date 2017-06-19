require 'rpm_spec_file'

#
# Util to get database details from our rails config.
#
def get_db_conf(env='development')
  Rails.configuration.database_configuration[env]
end

#
# Util to build user and passwd options for mysql commands
#
def sql_user_opts(db_conf)
  user_opt = "--user=#{db_conf['username']}"
  password_opt = "--password='#{db_conf['password']}'"
  "#{user_opt} #{password_opt if db_conf['password'].present?}".strip
end

#
# A helper for asking for user input
#
def ask_for_user_input(msg=nil, opts={})
  print msg if msg
  print ": "
  STDOUT.flush
  if opts[:password]
    system "stty -echo"
    result = STDIN.gets
    system "stty echo"
    puts
  else
    result = STDIN.gets
  end
  result.chomp
end

#
# For asking a yes/no question. Returns a boolean.
#
def ask_for_yes_no(msg)
  ['y','yes'].include?(ask_for_user_input("#{msg} [y/N]").strip.downcase)
end

#
# A helper for asking user to press any key to continue
#
def ask_to_continue_or_cancel(msg=nil)
  puts msg if msg
  print "(Ctrl-C to cancel or any key to continue)"
  STDOUT.flush
  STDIN.getc
end

def make_bug_list_link(bug_ids)
  "https://bugzilla.redhat.com/buglist.cgi?bug_id=#{ERB::Util.url_encode(bug_ids.compact.sort_by(&:to_i).join(","))}"
end

def get_bug_list_from_changelog
  changelog = RpmSpecFile.current.changelog
  make_bug_list_link(changelog.map { |l| l.match(/Bug (\d+) /)[1] })
end

#
# Writing a file helper
#
def write_content_to_file(file_name, content)
  File.open(file_name, 'w') { |file| file.write(content); file.flush }
end

#
#
# Prevent a task from running in any environment except development.
#
# Not useful by itself but use it with other tasks like this:
#
#   task :my_task => [:environment, :development_only] do
#     # This should only run in development
#     ...
#   end
#
desc "Raise an error if we are not in a development environment"
task :development_only => :environment do
  raise "This task is only for development environments! The current environment is '#{Rails.env}'." unless Rails.env.development?
end

#
# Prevent a task from running in a production environment.
#
# Example:
#
#   task :my_task => [:environment, :not_production] do
#     # This should never run in production
#     ...
#   end
#
desc "Raise an error if we are in the production environment"
task :not_production => :environment do
  raise "This task is not for production environments!" if Rails.env.production?
end

#
# A helper that can check if you have a valid local kerb ticket
# (Beware, it is not particular, any ticket will do...)
#
def has_local_kerb_ticket
  %x{klist -s && echo OK}.chomp == 'OK'
end

#
# A task that ensures user has a current valid kerberos ticket.
# Will ask them to authenticate if they don't.
#
# Used when brewing things (in deploy.rake and publican.rake)
#
desc "Ensure local user has a valid kerberos ticket"
task :ensure_local_kerb_ticket => :not_production do
  while !has_local_kerb_ticket do
    puts "Can't find a local kerberos ticket. Please authenticate with kerberos."
    # Actually this throws an exception if your auth fails,
    # so the while loop probably won't do anything...
    sh "kinit"
  end
  puts "Kerberos ticket okay"
end

#
# Perform arbitrary file hackery..
# Using this in deploy:release_bump
#
def sed_hack_on_file(file_name, match_regex, replace_with)
  original_content = File.read(file_name)
  new_content = original_content.gsub(match_regex, replace_with)
  if new_content != original_content
    File.open(file_name, 'w') { |file| file.write(new_content) }
  else
    puts "No change to file during sed hackery..."
  end
end

#
# Parse any file with ERB
#
def parse_file_as_erb(source_file, locals={})
  helpers = locals.delete(:helpers)
  erb_struct = Class.new(OpenStruct) do
    include ERB::Util
    include helpers if helpers
  end

  contents = File.read(source_file)
  b = erb_struct.new(locals).instance_eval { binding }
  ERB.new(contents).result(b)
end

#
# Helper for using erb templates in lib/tasks/templates
#
def render_template(template_name, locals={})
  parse_file_as_erb("#{Rails.root}/lib/tasks/templates/#{template_name}.erb", locals)
end

def render_template_to_public(template_name, locals={})
  write_content_to_file("#{Rails.root}/public/#{template_name}", render_template(template_name, locals))
end

def render_markdown_to_html_file(markdown_file)
  sh "pandoc --from=markdown --to=html --email-obfuscation=none --output='#{markdown_file}.html' '#{markdown_file}'"
end

def view_html_template(template_name, locals)
  write_content_to_file(tmp_file='/tmp/_et_tmp.html', render_template(template_name, locals))
  puts "Generated content in #{tmp_file}"

  # TODO: Starting firefox doesn't work when developing on a headless VM.
  # To workaround this I have been scp-ing the file to my workstation.
  # Maybe could put it in ./public dir or set DISPLAY to make it work somehow.
  #sh "firefox #{tmp_file}"
end

#
# Quick hack to get some notification recipients from our ansible inventory
#
def team_member_emails_from_inventory
  YAML.load_file("#{Rails.root}/ansible/inventory/group_vars/et-servers")['email_addresses'].slice('developers','qe').values.flatten
end
def team_member_usernames_from_inventory
  team_member_emails_from_inventory.map{|e|e.split('@').first}
end

#
# Quick hack to pull some data from Teiid. Use at your own risk.
# Notice the use of the default psql separator.
#
def get_data_from_teiid(sql)
  %x{echo "#{sql}" | env PSQL_OPTS=-At examples/teiid_sql/teiid_query.sh}.split("\n").map{|l|l.split('|')}
end

#
# We can figure out the latest deploy request JIRA task by doing a JIRA search
#
def get_jira_deploy_task
  jira_search_url = 'https://projects.engineering.redhat.com/rest/api/2/search'
  jira_query = "Project = ERRATA AND Type = Task AND labels = pntdevops-sysops-deploy ORDER BY updated Desc"
  response_json = %x{ curl -s -H "Content-Type: application/json" \
    "#{jira_search_url}?jql=#{CGI.escape(jira_query)}&maxResults=1" }
  response = JSON.load(response_json)
  raise "Query returned no issues, aborting. Query: #{jira_query} Response: #{response}" if response_json.blank? || response['issues'].blank?
  response['issues'].first
end

#
# Not really using these much
# (but see dev_bug_comment.rake)
#
def get_current_branch_from_git
  %x{ git rev-parse --abbrev-ref HEAD }.chomp
end

def get_current_commit_hash_from_git
  %x{ git log --format=%h -n1 }.chomp
end

def get_master_commit_hash_from_git
  %x{ git log master --format=%h -n1 }.chomp
end
