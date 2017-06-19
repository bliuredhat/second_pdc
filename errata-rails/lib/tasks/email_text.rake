#
# This is for generating boilerplate text for release announcements etc,
# (and has nothing to do with Errata Tool emails).
#
# Ideas:
#  - Actually send the emails
#
namespace :email_text do


  def changelog_text
    @spec.changelog.join
  end

  def changelog_count
    @spec.changelog.count
  end

  def bug_list_link
    "https://bugzilla.redhat.com/buglist.cgi?query_format=advanced&f1=flagtypes.name&o1=substring&v1=errata-#{VER}%2B"
  end

  def release_notes_link
    "https://engineering.redhat.com/docs/en-US/Application_Guide/60.Release/html/Errata_Tool/rel-notes-#{VER.sub('.','-')}-release-notes-for-version-#{VER}.html"
  end

  def is_hotfix?
    VER !~ /\.0$/
  end

  task :setup do
    @spec = RpmSpecFile.current
    VER = @spec.version
    REL = @spec.release
  end

  # We can get the deploy time by reading this file
  def time_of_release
    @_time_of_release ||= `curl -s http://errata.devel.redhat.com/installed-timestamp.txt`.chomp
  end

  # https://docs.engineering.redhat.com/display/Policy/Release+Announcement+template+-+example
  desc "Generate content for release announcement"
  task :announce => [:setup, :environment] do
    deployed_time = time_of_release
    deploy_task = get_jira_deploy_task

    jira_task_id = ENV['TASK'] || deploy_task['key'] or raise "Please specify the JIRA task id, eg TASK=ERRATA-3363"
    deployed_by = ENV['DEPLOYED_BY'] || deploy_task['fields']['assignee']['displayName'] or raise "Please specify who deployed the release, eg DEPLOYED_BY='Deployed By'"
    your_name = ENV['YOUR_NAME'] || ENV['USER'].present? && `getent passwd $USER | cut -d: -f5`.chomp or raise "Please specify your name, eg YOUR_NAME='Your Name'"

    puts "Deployed time: #{deployed_time}"
    puts "Deploy task id: #{jira_task_id}"
    puts "Deployed by: #{deployed_by}"
    puts "Your name: #{your_name}"

    release_notes = "#{Rails.root}/publican_docs/Release_Notes/markdown/Rel_Notes_#{VER.gsub('.','_')}.md.erb"
    if File.exist?(release_notes)
      # Second paragraph ought to be a short overview
      overview = File.read(release_notes).split("\n\n")[3].gsub("\n", ' ')
      has_release_notes = true
    else
      # Fall back to this for a hotfix with no release notes
      overview = "<!-- Add sentence here maybe -->Since this is a minor release there are no release notes."
      has_release_notes = false
    end

    %w[txt md].each do |mode|
      text_output = render_template('announce_email.text', {
        :mode => mode,
        :full_name => "#{VER}-#{REL}",
        :short_name => VER,
        :changelog_text => changelog_text,
        :changelog_count => changelog_count,
        :overview => overview,
        :url_date => Time.now.strftime('%Y/%m/%d'),
        :day => Time.now.day,
        :release_time => deployed_time,
        :bugs_link => get_bug_list_from_changelog,
        :jira_task_id => jira_task_id,
        :deployed_by => deployed_by,
        :your_name => your_name,
        :has_release_notes => has_release_notes,
      })
      write_content_to_file("public/announce.#{mode}", text_output)
    end

    # For plain text emails it looks better without the markdown link markup..
    sed_hack_on_file('public/announce.txt', /\[([^\]]+)\](\[\d+\])/, '\1 \2')
    sed_hack_on_file('public/announce.txt', /^(\[\d+\]): /, '\1 ')

    puts "Wrote public/announce.txt and public/announce.md. (See https://docs.engineering.redhat.com/x/QgAgAg )."
  end

  desc "Generate content for a scheduling enquiry email for eng-ops"
  task :scheduling_enquiry => [:setup] do
    puts render_template('scheduling_enquiry.text', {
      :full_name => "#{VER}-#{REL}",
      :teiid_update_required => ENV['TEIID'] == '1',
      :schema_changes => ENV['SCHEMA'] == '1',
      :short_name => VER,
      :changelog_text => changelog_text,
      :bugs_link => get_bug_list_from_changelog,
    })
  end

end
