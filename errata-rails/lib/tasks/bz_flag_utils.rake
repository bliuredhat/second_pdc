#
# (NB: This is not really part of Errata Tool)
#
# I need to bulk update some CDW release flags and for
# convenience want to use our existing Bugzilla::Rpc class.
#
# Note: This does not use the password that ET normally uses
# to connect to Bugzilla.
#
# See https://bugzilla.redhat.com/docs/en/html/api/Bugzilla/WebService/Flag.html
#
namespace :bz_flag_utils do

  def do_bugzilla_query(remote_method, data)
    server = Bugzilla::Rpc::BugzillaConnection.new('bugzilla.redhat.com', true)
    server.call('User.login', {'login' => $username, 'password' => $password})
    server.call(remote_method, data)
  end

  def bugs_with_status(status, merge_params={})
    response = do_bugzilla_query('Bug.search', {
      :query_format   => 'advanced',
      :product        => 'Errata Tool',
      :bug_status     => status,
      :include_fields => %w[id summary bug_status],
      :order          => 'bug_id DESC',
    }.merge(merge_params))

    response['bugs']
  end

  task :get_username_password do
    $username = ENV['BZ_USER'] || "#{ENV['USER']}@redhat.com" #ask_for_user_input('Bugzilla user')
    $password = ask_for_user_input('Bugzilla password', :password=>true)
  end

  task :get_bug_id do
    $bug_id = ENV['BUG'] or raise "Must specify a bug id, eg:\nrake bz_flag_utils:read_flags BUG=740819"
  end

  desc "Read a bug's flags"
  task :read_flags => [:environment, :get_bug_id, :get_username_password] do
    result = do_bugzilla_query('Bug.get', { :ids => [$bug_id], :include_fields => [:flags] })
    puts "#{$bug_id} flags: #{result['bugs'][0]['flags'].map { |f| "#{f['name']}#{f['status']}" }.join(", ")}"
  end

  desc "Read a bug's flags (long version)"
  task :read_flags_long => [:environment, :get_bug_id, :get_username_password] do
    # The response for this is long, verbose and confusing.
    # It contains details of flags about that are not active.
    # So not going to use it...
    pp do_bugzilla_query('Flag.get', { :ids => [$bug_id] })
  end

  def add_cdw_flag(bug_ids, flag_name, status='?')
    pp do_bugzilla_query('Flag.update', { :ids => bug_ids, :nomail => true, :updates => [{ :name => flag_name, :status => status }] } )
  end

  def remove_cdw_flag(bug_ids, flag_name)
    pp add_cdw_flag(bug_ids, flag_name, 'X')
  end

  def add_cdw_flag_remove_old(bug_ids, old_flag_name, new_flag_name)
    pp do_bugzilla_query('Flag.update', { :ids => bug_ids, :nomail => true, :updates => [
      # Remove the old flag
      { :name => old_flag_name, :status => 'X' },
      # Propose the new flag
      { :name => new_flag_name, :status => '?' },
    ] } )
  end

  # Test before running future_maint_to_4_0 and add_32_flag_to_3x
  desc "Add flag to a bug"
  task :add_flag_to_bug => [:environment, :get_bug_id, :get_username_password] do
    flag_name = ENV['FLAG'] or raise "must specify a flag to set"
    add_cdw_flag([$bug_id], flag_name)
  end

  def add_to_cc_list(bug_ids, user_emails)
    pp do_bugzilla_query('Bug.update', { :ids => bug_ids, :nomail => true, :cc => { :add => user_emails} })
  end

  desc "Roll bugs forward"
  task :roll_flags_forward => [:environment, :get_username_password] do
    # Get flags from command line. Should leave off the the ?
    from_flag = ENV['FROM_FLAG'] or raise "Must specify FROM_FLAG"
    to_flag = ENV['TO_FLAG'] || from_flag.next

    response = do_bugzilla_query('Bug.search', {
      # The params are the same as Bugzilla advanced web search
      :query_format   => 'advanced',
      :product        => 'Errata Tool',
      :f1             => 'flagtypes.name',
      :o1             => 'substring',
      :v1             => "#{from_flag}?",
      # Most would be NEW or ASSIGNED I guess, but let's specify all unclosed
      :bug_status     => '__open__',
      #:bug_status     => 'CLOSED',
      :include_fields => %w[id summary status flags]
    })

    flagged_bugs = response['bugs']

    # If you want to do just one for a test...
    #flagged_bugs = flagged_bugs[0..0]

    puts "\n================================================="
    flagged_bugs.each do |bug|
      puts "#{bug['id']} - #{bug['summary']} - #{bug['status']} - #{bug['flags'].map{|f|"#{f['name']}#{f['status']}"}.join(', ')}"
    end
    puts "=================================================\n\n"

    puts "Found #{flagged_bugs.count} bugs with flag #{from_flag} proposed. (See above)."
    ask_to_continue_or_cancel "About to remove flag '#{from_flag}' and propose flag '#{to_flag}' for all these bugs.\n"

    flagged_bugs.map{ |b| b['id'].to_i }.each_slice(20) do |bug_ids|
      puts "\nProcessing #{bug_ids.inspect}...\n"
      if to_flag.present?
        add_cdw_flag_remove_old(bug_ids, from_flag, to_flag)
      else
        # (Specify empty TO_FLAG= and it will just remove the FROM_FLAG one)
        remove_cdw_flag(bug_ids, from_flag)
      end
    end
  end

  desc "Add cc on all open ET bugs"
  task :add_cc_to_all_open_bugs => [:environment, :get_username_password] do
    email_to_add = ENV['CC_USER'] or raise "Must specify CC_USER=someone@redhat.com"

    response = do_bugzilla_query('Bug.search', {
      # The params are the same as Bugzilla advanced web search
      :query_format   => 'advanced',
      :product        => 'Errata Tool',
      :bug_status     => '__open__',
      :include_fields => %w[id summary status cc]
    })

    all_bugs = response['bugs'].reject{ |b| b['cc'].include?(email_to_add) }

    # If you want to do just one for a test...
    #all_bugs = all_bugs[0..0]

    all_bugs.each { |bug| puts "#{bug['id']} - #{bug['summary']} - #{bug['status']} - #{bug['cc'].inspect}" }
    puts "\nFound #{all_bugs.count} open bugs"
    ask_to_continue_or_cancel "About to add #{email_to_add} as cc to all these bugs.\n"

    all_bugs.map{ |b| b['id'].to_i }.each_slice(20) do |bug_ids|
      puts "\nProcessing #{bug_ids.inspect}...\n"
      add_to_cc_list(bug_ids, [email_to_add])
      sleep 2 # be nice
    end
  end

  desc "Prepare change log for spec file"
  task :change_log_text => [:environment, :get_username_password] do
    bug_status = ENV['BUG_STATUS'] || 'VERIFIED'
    bugs_with_status(bug_status).each do |bug|
      puts "- Bug #{bug['id']} #{bug['summary']}"
    end
  end

  desc "Prepare bug list link (set BUG_STATUS as required, default is VERIFIED)"
  task :bug_list_link => [:environment, :get_username_password] do
    bug_status = ENV['BUG_STATUS'] || 'VERIFIED'
    puts make_bug_list_link(bugs_with_status(bug_status).map{|bug|bug['id']})
  end

  desc "Prepare bug list link of all modified bugs"
  task :bug_list_link_modified => [:environment, :get_username_password] do
    puts make_bug_list_link(bugs_with_status('MODIFIED').map{|bug|bug['id']})
  end

  def get_issues_in_sprint(sprint_name)
    jira_search_url = 'https://projects.engineering.redhat.com/rest/api/2/search'
    jira_query = "Project = ERRATA AND Sprint = '#{sprint_name}'"
    response_json = %x{ curl -s -H "Content-Type: application/json" \
      "#{jira_search_url}?jql=#{CGI.escape(jira_query)}&maxResults=200" }
    response = JSON.load(response_json)
    #puts response.except('issues').inspect
    response['issues']
  end

  #
  # Output some text suitable for email or pasting into etherpad
  #
  # Example usage:
  #   rake bz_flag_utils:sprint_items SPRINT=7
  #
  desc "List issues in sprint"
  task :sprint_items do
    version_release = RpmSpecFile.current.version_release
    ver = version_release.split('.')[0..1].join('.')
    sprint_num = ENV['SPRINT'] or raise "Please specify the sprint number, e.g. SPRINT=7"
    link_only = ENV['SHORT']

    sprint_name = "#{ver} Sprint #{sprint_num}"
    puts "#{'<h2>' unless link_only}#{sprint_name} (#{Time.now.strftime('%F %T')})#{'</h2>' unless link_only}\n\n"
    issues = get_issues_in_sprint(sprint_name)
    unless issues && issues.any?
      puts("Nothing found!")
      next
    end

    issues.each do |issue|
      # Massage some info we want then put it back in the hash
      bz_statuses = %w[NEW ASSIGNED POST MODIFIED ON_QA VERIFIED RELEASE_PENDING CLOSED]
      issue['_labels'] = labels = issue['fields']['labels'].reject{|l|l=~/^errata-/}
      issue['_bz_status'] = bz_status = labels.find{ |label| bz_statuses.include?(label) }
      issue['_bz_sort'] = bz_statuses.find_index(bz_status.to_s) || -1
    end

    bug_ids = []
    issues.group_by{ |i| (i['fields']['assignee']||{})['name']||'Unassigned' }.sort_by{ |k,v| k == 'Unassigned' ? 1 : rand }.each do |who, issues|
      puts "<h3>#{'Assigned to ' unless who == 'Unassigned'}#{who}</h3><ul>\n\n" unless link_only

      issues.sort_by{ |i| [-i['_bz_sort'], i['fields']['summary']] }.each do |issue|
        key = issue['key']
        fields = issue['fields']
        summary = fields['summary']
        bug_id = fields['customfield_10700'].try(:[],'bugid')
        points = fields['customfield_10002'].inspect
        labels = issue['_labels']
        assignee = (fields['assignee']||{})['name']
        jira_url = "https://projects.engineering.redhat.com/browse/#{key}"
        bz_url = "https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
        bug_ids << bug_id if bug_id

        next if link_only
        puts "<li>#{summary} (#{key}) "
        print bug_id.present? ? "<a href='#{bz_url}'>#{bug_id}</a>" : "<a href='#{jira_url}'>#{key}</a>"
        print ' ' + (labels + [assignee] + ["#{points.to_s.sub(/\.0$/,'')} pts"]).compact.join(", ")
        puts "</li>\n\n"

      end
      puts "</ul>" unless link_only
    end

    puts make_bug_list_link(bug_ids) if link_only
  end

end
