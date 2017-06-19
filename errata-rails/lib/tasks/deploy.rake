#
# Some tasks for building RPMs for deployment
#
# For test builds, release of the RPM can be overridden by setting RELEASE on
# the command line, e.g. rake deploy:brew_scratch_rpm RELEASE=1_myfeature
#
# See also:
#   Makefile
#   errata-rails.spec
#

namespace :deploy do
  require 'rexml/document'

  task :setup do
    @spec = RpmSpecFile.current
    RPMBUILD_DIR = "#{ENV['HOME']}/rpmbuild".freeze
    TMP_DIR = "/tmp/errata_rails_build".freeze
    # TODO: DRY up the version number.
    # #{VER}-#{REL} is probably the same as SystemVersion::VERSION
    WRITE_REL = ENV['RELEASE']

    SRPM = "#{RPMBUILD_DIR}/SRPMS/errata-rails-%s-%s%s.src.rpm" % [
      @spec.version,
      WRITE_REL || @spec.release,
      dist
    ]
  end

  desc "Build an rpm ready for deployment"
  task :build_src_rpm => [:setup] do
    # Do this so the tarball doesn't include generated doc files,
    # log files, etc
    rm_rf TMP_DIR
    sh "git clone .git #{TMP_DIR}"

    # This updates all the books and copies their generated content
    sh "rake publican:all_books DO=add_to_src_rpm HTML_ONLY=1"

    # This generates the rdoc docs and copies their generated content
    sh "rake apidocs:add_to_src_rpm"

    cd TMP_DIR
    unless WRITE_REL.nil?
      sh "sed -i -r -e 's|^Release:.+|Release: #{WRITE_REL}%{?dist}|' #{@spec.filename}"
      File.open('lib/system_version.rb', 'w') do |io|
        io.write("module SystemVersion; VERSION = %{#{@spec.version}-#{WRITE_REL}}; end")
      end
    end

    # Creates a tarball file in #{TMP_DIR}/errata-rails-2.2.tar.gz
    # (Note: We could move the create-archive commands out of Makefile and run them directly here)
    sh "make create-archive VERSION=#{@spec.version}"

    mkdir_p ["#{RPMBUILD_DIR}/SOURCES", "#{RPMBUILD_DIR}/SPECS"]

    # Copy the tarball file and the spec into the rpmbuild dir
    cp "errata-rails-#{@spec.version}.tar.gz", "#{RPMBUILD_DIR}/SOURCES"
    cp @spec.filename,                         "#{RPMBUILD_DIR}/SPECS"

    # Create an rpm from the tarball
    cd "#{RPMBUILD_DIR}/SPECS"
    sh "rpmbuild --nodeps -bs --define 'dist #{dist}' #{@spec.filename}"
  end

  def dist
    '.el6'
  end

  def build_target
    'errata-rails-rhel-6-candidate'
  end

  task :brew_scratch_rpm_from_src_rpm => [:setup, :ensure_local_kerb_ticket] do
    # Brew build it (notice the --scratch)
    sh "brew build --scratch #{build_target} #{SRPM}"
  end

  task :brew_rpm_from_src_rpm => [:setup, :ensure_local_kerb_ticket] do
    # Brew build it
    sh "brew build #{build_target} #{SRPM}"
  end

  desc "Add annotated tag after build"
  task :add_tag_after_build => [:setup] do
    task_id = ENV['TASK'] || get_jira_deploy_task['key'] or raise "Please specify deploy request JIRA id, e.g. TASK=ERRATA-3445"

    # Determine build id
    nvr = "errata-rails-#{@spec.version_release}#{dist}"
    buildinfo = `brew buildinfo #{nvr}`
    brew_build_id = buildinfo.lines.grep(/^BUILD:/).first.match(/\[(\d+)\]/)[1]

    # Prepare annotation
    puts msg = <<-eos.strip_heredoc
      Brewed #{nvr} for prod deploy

      Build: https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=#{brew_build_id}
      Deploy: https://projects.engineering.redhat.com/browse/#{task_id}
    eos

    # Create the tag, ask first
    ask_to_continue_or_cancel "\nCreate annotated tag '#{@spec.version_release}' with the above annotation?"
    sh "git tag -a #{@spec.version_release} -m '#{msg}'"

    # Push the tag
    sh "git push origin --follow-tags --dry-run"
    ask_to_continue_or_cancel "Redo the push tags without --dry-run?"
    sh "git push origin --follow-tags"
  end

  task :warn_no_release => [:setup] do
    unless WRITE_REL
      puts "For a scratch build you should probabably set RELEASE=something on the command line. Example:"
      puts ""
      puts "  rake deploy:brew_scratch_rpm RELEASE=scratch.`git log -1 --format=%h`"
      puts ""
      exit unless ask_for_yes_no("Continue anyway without specifying RELEASE?")
    end
  end

  desc "Build an rpm and send it to Brew (as a scratch build)"
  task :brew_scratch_rpm => [:setup, :warn_no_release, :build_src_rpm, :brew_scratch_rpm_from_src_rpm]

  # Note, for a production release, this is as far as it goes. The actual
  # deploy is done by eng-ops-prod. So the next step is so to find the rpm yourself,
  # create an eng-ops-prod ticket, etc.
  desc "Build an rpm and send it to Brew (non-scratch build)"
  task :brew_rpm => [:setup, :build_src_rpm, :brew_rpm_from_src_rpm]

  # What follows are some hacks to semi-automate a deploy to dev-stage.

  #------------------------------------------------------------------------
  #
  # Hack to run a brew command and parse
  # the response as a python literal object.
  #
  def brew_command_parse_response(brew_cmd, debug_show=false)
    #
    # Run the brew command
    #
    puts "Running #{brew_cmd}" if debug_show
    python_resp_text = %x{brew #{brew_cmd}}

    #
    # Brew spits out python object literal dumps.
    # Let's parse them with this NASTY HACK!
    # (Replace colon with hash rocket and fudge None/True/False)
    #
    puts "Brew response:\n#{python_dump}" if debug_show
    # Not sure what scope None, True, False will be defined in... like I said, nasty... :)
    eval "None = nil; True = true; False = false; #{python_resp_text.gsub(/':/, "'=>")}"
  end

  #
  # Figure out what your brew user id is
  #
  def get_brew_user_id
    brew_command_parse_response("call getLoggedInUser")['id']
  end

  #
  # Get info on latest task
  # (Hopefully it is the one you have just built)
  #
  def get_latest_task_info
    today = Time.now.beginning_of_day.utc.to_s(:Y_m_d)
    owner_id = get_brew_user_id
    brew_command_parse_response(%{call "listTasks" --python '{"createdAfter":"#{today}", "owner":#{owner_id}, "method":"buildArch"}'}).
      # Sort by id desc.
      sort_by{ |t| -t['id'] }.
      # Get the newest one.
      first
  end

  #
  # There is a result field that contains some info in xml about the task's
  # output. Parse that and look for the rpm location.
  #
  def get_latest_rpm_url(debug_show=false)
    xml_result = get_latest_task_info['result']
    puts xml_result if debug_show
    # Do some fast and loose xml parsing... (TODO: be less fast and less loose)
    rpm_location = REXML::Document.new(xml_result).elements.to_a('//string').map{ |e| e.text }.grep(/errata-rails.*\.el6eso\.noarch\.rpm$/).first
    raise "Can't find noarch rpm!" unless rpm_location
    "http://download.devel.redhat.com/brewroot/work/#{rpm_location}"
  end

  #
  # Similar to eng_ops_email_template below but for PDI
  #
  desc "Generate text for a deploy request (PDI version)"
  task :deploy_request_text => :setup do
    nvr = "errata-rails-#{@spec.version_release}.el6"
    buildinfo = `brew buildinfo #{nvr}`
    brew_build_id = buildinfo.lines.grep(/^BUILD:/).first.match(/\[(\d+)\]/)[1]

    puts render_template('deploy_request.text', {
      :ver => @spec.version,
      :rel => @spec.release,
      :ver_rel => @spec.version_release,
      :nvr => nvr,
      :changelog => @spec.changelog.join,
      :bug_count => @spec.changelog.length,
      :this_tag => @spec.version_release,
      :prev_tag => @spec.previous_tag,
      :brew_build_id => brew_build_id,
      :bug_list_link => get_bug_list_from_changelog,
    });
  end

  #
  # Let's generate some email text to copy/paste.
  # Note: If there are migrations, config changes or dependency changes
  # you need to manually describe them.
  #
  desc "Generate a email template to send to eng-ops as an RT ticket"
  task :eng_ops_email_template => [:setup] do
    # Get the brew build id and the rpms
    nvr = "errata-rails-#{@spec.version}-#{@spec.release}.el6eso"
    buildinfo = `brew buildinfo #{nvr}`
    brew_build_id = buildinfo.lines.grep(/^BUILD:/).first.match(/\[(\d+)\]/)[1]
    rpm_files = buildinfo.lines.grep(/^\/mnt\/redhat\//).join.chomp

    # Read the changelog and prev tag out of the spec file
    # Presume you tagged carefully and done a git push --tag
    this_tag = @spec.version_release
    changelog = @spec.changelog.join
    prev_tag  = @spec.previous_tag

    puts <<-EOT.strip_heredoc
      Ready to display a generated template for the deploy email.
      Copy/paste it, edit as required, then email to eng-ops@redhat.com
      or to the 'Deploy Requests' list at
      https://docs.engineering.redhat.com/display/HTD/Errata+Tool+Mailto+Links

      Notes:
       * Any config changes, dependencies, or other information should be described manually.
       * You should also give details about schema changes if there are any.

      (Ctrl-C to cancel displaying the email template).
    EOT

    puts render_template('deploy_email.text', {
      :ver => @spec.version,
      :rel => @spec.release,
      :changelog => changelog,
      :this_tag => this_tag,
      :prev_tag => prev_tag,
      :brew_build_id => brew_build_id,
      :rpm_files => rpm_files,
      :bug_list_link => get_bug_list_from_changelog,
    });

  end

  def rc_announce_email_text(rpm_url)
    migration_required = ask_for_yes_no("Migration required?")
    %{

===============================================================
Errata Tool #{@spec.version_release} now available for testing and QE

Errata Tool #{@spec.version_release} is now installed on the Errata Tool devel server at:

  https://errata-devel.app.eng.bos.redhat.com/

The rpm can be downloaded from:

  #{rpm_url}

To install:

  wget #{rpm_url}
  sudo yum localinstall --nogpgcheck #{rpm_url.split('/').last}
  sudo -u erratatool touch /var/www/errata_rails/tmp/restart.txt

This release #{migration_required ? 'DOES' : 'does not'} require a database migration#{migration_required ? ':' : '.'}
#{"
  sudo su erratatool
  cd /var/www/errata_rails
  RAILS_ENV=staging rake db:migrate
  touch tmp/restart.txt
" if migration_required}
For bug lists see:

  http://file.bne.redhat.com/~sbaird/et-bugs.shtml

===============================================================
}
  end

  #
  # Using brew commands and the hacky methods above, download the rpm we just built
  # using wget on devstage.
  #
  # (Require :environment just because it's easy to use the date formatter and the beginning_of_day
  # in get_latest_task_info above...)
  #
  task :rpm_to_devstage => [:setup, :environment] do
    upload_host = 'errata-devel.app.eng.bos.redhat.com'
    rpm_url     = get_latest_rpm_url
    rpm_file    = rpm_url.split(/\//).last
    sh "ssh #{upload_host} wget -q #{rpm_url} -O /tmp/#{rpm_file}"

    # Not quite one button deploy yet...
    puts "Now to deploy do this on #{upload_host}:"
    puts " sudo sh -c 'yum localinstall --nogpgcheck /tmp/#{rpm_file} && touch /var/www/errata_rails/tmp/restart.txt'"
    puts ""
    puts 'Or if you have done `source /var/www/errata_rails/script/bash_utils.sh` you can just do this:'
    puts "  etupdate"
    puts ""

    # Text for email
    puts rc_announce_email_text(rpm_url)
  end

  #
  # This is the 'do it all' task for dev stage deploy. It will build a source rpm, brew build a noarch rpm,
  # download it to dev stage.
  #
  desc "Build and upload to devstage"
  task :devstage_deploy => [
    :brew_scratch_rpm,
    :rpm_to_devstage,
  ]

  #
  # For production deploy there is less automation.
  # It's up to eng-ops-prod to sign the rpm then install it.
  #
  desc "Build ready for production deploy"
  task :prepare_prod_deploy => [
    :brew_rpm,
    :eng_ops_email_template,
  ]

  #
  # Use only to bump from one rc release number to the next
  # Don't use it for actual releases.
  #
  desc "Try to automatically bump the rc in spec file and lib/system_version.rb"
  task :release_bump => [:setup] do
    version_file = 'lib/system_version.rb'
    raise "Seems like you aren't ready for this" unless `git diff #{@spec.filename}; git diff lib/system_version.rb; git diff --staged;`.strip.blank?
    current_version = @spec.version
    old_release = @spec.release
    rc_num = old_release.match(/_rc(\d+)$/)[1] or raise "Can't parse rc number"
    # Was using old_release.next but it doesn't work if rc_num > 9, you get rd0 :)
    new_release = old_release.sub(/(_rc)(\d+)/,"\\1#{rc_num.to_i + 1}")

    ask_to_continue_or_cancel("Will attempt to bump version number to #{current_version}-#{new_release} and commit the change. Okay?")

    sed_hack_on_file(
      @spec.filename,
      /^(Release:\s+)(#{Regexp.escape(old_release)})(%)/m,
      "\\1#{new_release}\\3"
    )

    sed_hack_on_file(
      version_file,
      /(VERSION = '#{Regexp.escape(current_version)}\-)(#{Regexp.escape(old_release)})(')/m,
      "\\1#{new_release}\\3"
    )

    sh "git add #{@spec.filename} #{version_file}"
    sh "git commit #{@spec.filename} #{version_file} -m 'Bump version to #{current_version}-#{new_release} for scratch build and deploy'"

    # So you can see it..
    sh "git show HEAD"

    current_branch = get_current_branch_from_git
    ask_to_continue_or_cancel("Will now do a `git push origin #{current_branch}`. Okay?")
    sh "git push origin #{current_branch}"

    ask_to_continue_or_cancel("Will tag as #{current_version}-#{new_release}. Okay?")
    sh "git tag #{current_version}-#{new_release}"

    ask_to_continue_or_cancel("Will now `git push origin --tags`. Okay?")
    sh "git push origin --tags"
  end
end
