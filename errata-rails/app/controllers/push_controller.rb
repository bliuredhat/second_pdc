require "cgi"
require "set"

class PushController < ApplicationController
  include SharedApi::ErrataPush, ReplaceHtml

  STATUS_CHECK_INTERVAL = 3
  before_filter :pusherrata_restricted, :only => [ :mail, :live, :ftp, :confirm_empty_ftp ]
  before_filter :find_errata, :except => [:cdn_file_list,
                                          :check_push_status,
                                          :file_pub_failure_ticket,
                                          :index,
                                          :push_results,
                                          :rhn_file_list,
                                          :rhn_push_log,
                                          :stop_job,
                                          :update_job_status]
  before_filter :prepare_push_policies, :only => [:push_errata, :push_errata_submit]
  before_filter :prepare_rhn_push_info, :prepare_cdn_push_info, :only => :push_errata
  before_filter :find_push_job, :only => [:stop_job, :update_job_status]

  verify :method => :post, :only => [:confirm_empty_ftp, :file_pub_failure_ticket, :push_errata_submit]

  def check_push_status
    job = PushJob.find(params[:id])
    if params[:last_update] && !(job.updated_at.to_i > params[:last_update].to_i)
      head :not_modified
      return
    end
    respond_to do |format|
      format.js do
        js = replace_html_to_string :push_log, job.log
        js += replace_html_to_string :job_status, job.status
        #page.assign 'last_update', job.updated_at.to_i
        if job.is_finished?
          js += js_for_html 'stop_push_button', ""
          #page.assign 'check_update', false
        end
        render_js js
      end
      # Should not get here but.. see bug 729534
      format.any { render :nothing => true }
    end
  end


  def confirm_empty_ftp
    unless ftp_paths.empty?
      redirect_to_error!("Advisory #{@errata.fulladvisory} has files to push. Cannot waive a non-empty ftp list!")
      return
    end
    @errata.pushed = 1
    @errata.save
    msg = "Waived FTP Push for empty file list confirmed."
    @errata.comments.create(:text => msg)
    flash_message :notice, msg
    redirect_to :action => :view, :controller => :errata, :id => @errata
  end

  def file_pub_failure_ticket
    job = PushJob.find params[:id]
    if job.problem_ticket_filed?
      flash_message :alert, "A problem ticket has already been filed."
    else
      Notifier.file_pub_failure_ticket(job, current_user).deliver
      job.problem_ticket_filed = true
      job.save(:validate => false)
      flash_message :notice, 'A ticket has been filed with release engineering'
    end
    redirect_to :action => :push_results, :id => job
  end

  def index
    redirect_to :action => :rhn_push_log
  end

  def oval
    @test = OvalTest.new(@errata)
    if Rails.env.production?
      bz = Bugzilla::Rpc.get_connection
      bz.reconcile_bugs(@errata.bugs.collect { |b| b.id })
      @errata = Errata.find(@errata.id)
    end
    render :action => 'errata_oval', :layout => false, :content_type => 'text/xml'
  end

  def push_history_for_errata
    @push_jobs = PushJob.find(:all,
                                 :conditions => ['errata_id = ?', @errata],
                                 :joins => [:pushed_by],
                                 :order => 'created_at desc')

    set_page_title "Push Results for #{@errata.advisory_name}"
  end

  def push_results
    extra_javascript 'push_results'
    @push_job = PushJob.find(params[:id])
    @errata = @push_job.errata
    pushtype = @push_job.class.to_s.split(/(?=[A-Z])/)
    pushtype.pop
    set_page_title "#{pushtype.join(' ')} results for #{@errata.advisory_name}"
    render :template => 'shared/push_results'
  end

  def rhn_push_log
    set_page_title 'Push Jobs'
    @rhn_push_jobs = PushJob.paginate(:page => params[:page],
                                      :order => 'push_jobs.created_at desc, errata_main.id, users.id',
                                      :include => [:errata, :pushed_by]
                                      )
  end

  def rhn_file_list
    hash = ErrataService.new.get_advisory_rhn_file_list(params[:id])
    respond_to do |format|
      format.json do
        render :layout => false,
        :json => hash.to_json
      end
      format.any do
        render :text => hash_to_string(hash),
        :layout => false
      end
    end
  end

  def cdn_file_list
    hash = ErrataService.new.get_advisory_cdn_file_list(params[:id])
    respond_to do |format|
      format.json do
        render :layout => false,
        :json => hash.to_json
      end
      format.any do
        render :text => hash_to_string(hash)
      end
    end
  end

  # Debugging method to display what the actual hash to be sent to RHN is.
  def show_hash
    hash = Push::Rhn.make_hash_for_push(@errata, current_user.login_name)
    respond_to do |format|
      format.json do
        render :layout => false,
        :json => hash.to_json
      end
      format.text do
        render :text => hash_to_string(hash)
      end
      format.html do
        @text = hash_to_string(hash)
        render :layout => false
      end
    end
  end

  def stop_job
    unless @push_job.is_finished?
      begin
        @push_job.cancel!(Push::PubClient.get_connection, current_user)
        flash_message :notice, "Push job stopped."
      rescue StandardError => e
        logger.warn "Error stopping push job: #{e.message}"
        flash_message :error, "Push job could not be stopped. #{e.message}"
      end
    end
    redirect_to :action => :push_results, :id => @push_job
  end

  def update_job_status
    Push::PubWatcher.perform
    flash_message :notice, 'Status updated.'

    redirect_to :action => :push_results, :id => @push_job
  end

  private

  #------------------------------------------------------------------------------
  # From here down is a big refactor of the push UI related to Bug 751076.
  #
  # Note: The way this is designed (for Bug 751076), is the code that handles
  # 'rhn live' pushes and 'rhn stage' pushes is combined so they are mostly
  # handled by the same methods, ie the rhn_push_* methods.  It might have
  # actually been cleaner to treat them separately since they are fairly
  # different. But am going to leave it as it as for now.
  #

  # push_errata is an action, flip back to public just for this method
  public

  #
  # This live url used to be in the request_rhnlive_push email body so redirect it...
  # The stage, ftp, cdn are probably not needed but lets redirect them also just in case.
  #
  def live;  redirect_to :action => :push_errata, :id => @errata.id; end
  def cdn;   redirect_to :action => :push_errata, :id => @errata.id; end
  def ftp;   redirect_to :action => :push_errata, :id => @errata.id; end
  def stage; redirect_to :action => :push_errata, :id => @errata.id, :stage => 1; end

  #
  # We are displaying the form only which shows push options to the user.
  #
  def push_errata
    @stage_only = params[:stage].present?
    extra_javascript %w[push_view]
  end

  #
  # This handles the actual push.
  #
  def push_errata_submit
    @user = current_user

    # Set page page name
    set_page_title get_push_page_name.html_safe

    @policies.select { |p| params[p.push_type].to_bool }.each do |policy|
      if policy.push_possible?
        target = resolve_params_for_policy(policy)
        push_request = PushRequest.new(@errata, [target], [policy])

        begin
          job = create_push_job(target, push_request)
        rescue StandardError => ex
          log_helper "Creating push job failed", :exception => ex
        end

        job_submit(job)

        enqueued = job.try(:in_queue?)
        add_message "<div class='push_notices'><h3>#{enqueued ? 'Enqueuing' : 'Doing'} <b>#{policy.push_type_name}</b> push...</h3>"

        add_message job ? "Ok" : "<p class='red bold'>#{policy.push_type_name} push FAILED!</p>"
        add_message '</div>'
        log_helper "Push Job Params: #{target.inspect}", :type => :debug

      else
        policy.errors.values.flatten.each { |m| add_message(m) }
      end
    end
  end

  # The rest of these are private and called from the push_errata action
  private

  def job_submit(job)
    return if job.blank?

    submit_opts = {:trace =>
      lambda{|msg| log_helper(msg, :type => :info)}}

    if params[:push_immediately] != '1' && job.can_enqueue?
      # enqueue rather than submit if possible
      job.enqueue!
      log_helper "#{job.class.model_name.human} id #{job.id} has been placed in the push queue.", :type => :info
    else
      job.submit!(submit_opts)
    end
  end

  # transforms push form parameters into a PushRequest::Target object
  # accepted by SharedApi
  def resolve_params_for_policy(p)
    target = p.push_target.to_s

    out = PushRequest::Target.new
    out.target = target

    # Note target/type mismatch ...
    # Options to be set on CdnLivePushJob are under a key named cdn_push_job :(
    these_params = params\
      .fetch(:push_options_fields, {})\
      .fetch("#{target}_push_job", {})

    # Note one significant difference here between this controller and
    # the API controller.  Here, we _always_ overwrite the default
    # options/tasks with the values provided by the form - even if
    # they are empty.  Defaults don't come into play at all.
    out.options = clean_checkbox_opts(these_params[:options] || {})

    [:pre_tasks, :post_tasks].each do |key|
      out.send("#{key}=", checked_keys(these_params[key] || {}))
    end

    out
  end

  #------------------------------------------------------------------------------
  # Utility methods for dealing with checkboxes in param hashes

  #
  # Remove the unchecked checkboxes and make it so the remaining keys
  # have a value of `true`.
  #
  # CdnPushJob pub_options seems to want a hash in this format.
  #
  # (Used to do it like this):
  #   params_hash.reject{ |k, v| v == '0' }.inject({}){ |h, (k, v)| h[k] = true; h }
  #
  def clean_checkbox_opts(params_hash)
    Hash[ checked_keys(params_hash).map{ |k| [k, true] } ]
  end

  #
  # Unchecked checkboxes get a value of '0' so remove them.
  # Returns the keys only, for use with push_job.pre_push_tasks etc.
  #
  # (The value.blank? test seems like a good idea, but really there
  # should only be '1' or '0').
  #
  def checked_keys(params_hash)
    params_hash.reject{ |key, value| value.blank? || value == '0' }.keys
  end

  #------------------------------------------------------------------------------

  #
  # Will show messages to the user once everything is done
  #
  def add_message(message,opts={})
    # Append the message to @messages
    (@messages ||= []) << message
  end

  def ftp_paths
    @ftp_paths ||= Push::Ftp.ftp_dev_file_map(@errata)
  end
  helper_method :ftp_paths

  #
  # Page title helper
  #
  def get_push_page_name
    "Push #{@submitting ? 'results' : 'options'} for #{@errata.fulladvisory} " +
    "<span class='superlight'>#{@errata.quoted_synopsis}</span>"
  end

  #
  # Log helper
  # (Maybe some version of this could go into ApplicationController later...)
  # You can also optionally add a message for the user
  #
  def log_helper(msg, opts={})
    # Default log type is :error
    log_type = opts[:type] || :error

    # Optionally pass in an exception object
    e = opts[:exception]

    # If given an exception object, append `e.message`
    msg << ": #{e.message}" if e

    # Log msg using the log_type, ie :debug, :info, :warn, :error, :fatal
    logger.send(log_type, msg)

    # Also log the backtrace if we have one
    logger.send(log_type, e.backtrace.join("\n")) if e && e.backtrace

    # Also add message to @messages for user feedback unless we're asked not to
    # (Presume you don't want to show users debug messages)
    if (!opts[:no_message] && log_type != :debug)
      # Retain vertical whitespace for longer messages.
      nicemsg = msg.gsub("\n", "<br/>\n")
      add_message(nicemsg)
    end
  end

  def prepare_push_policies
    @stage_only = params[:stage].present?
    @policies = Push::Policy.policies_for_errata(@errata, :staging => @stage_only)
  end

  #
  # Copied as-is from the old push_to_rhn method
  # This stuff gets displayed to the user underneath the form.
  #
  def prepare_rhn_push_info
    # TODO implement text_only stuff...
    if @errata.text_only?
      @channels = @errata.text_only_channel_list.channel_list.split(',')
      @rpms_to_upload = []
      @archives_to_upload = []
      @zstreams = []
      @fastrack = []
      @excluded_srpms = []
    else
      @channels = Set.new
      channel_map = Push::Rhn.errata_files(@errata, false)
      channel_map.each do |f|
        @channels.merge(f['rhn_channel'])
      end
      @channels = @channels.to_a.sort
      @zstreams = Set.new
      @fastrack = Set.new
      @channels.each do |c|
        @zstreams << "#{$1}.#{$2}.z" if c =~ /(\d)\.(\d)\.z/
        @fastrack << "RHEL #{$1}" if c =~ /-(\d)-fastrack/
        @fastrack << "RHEL 5" if c =~ /fastrack-5/
      end
      @zstreams = @zstreams.to_a.sort
      @fastrack = @fastrack.to_a.sort
      @rpms_to_upload = rpms_for_rhn(@errata)
      @archives_to_upload = archives_for_rhn(@errata)
      @excluded_srpms = @errata.build_mappings.for_rpms.select{ |map| FtpExclusion.is_excluded?(map.package, map.release_version) }.collect{ |map| map.brew_build.nvr }
    end
  end

  #
  # Prepare some stuff for a CDN push, will be used in the form.
  #
  def prepare_cdn_push_info
    service = ErrataService.new
    strings = [
      '# RPM content:',
      hash_to_string(service.get_advisory_cdn_file_list(@errata.advisory_name)),
      '# Non-RPM content:',
      hash_to_string(service.get_advisory_cdn_nonrpm_file_list(@errata.advisory_name)),
    ]
    @cdn_file_list_text = strings.join("\n")
    @docker_metadata_text = hash_to_string(service.get_advisory_cdn_docker_file_list(@errata.advisory_name)) if @errata.has_docker?
  end

  def find_push_job
    begin
      @push_job = PushJob.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      flash_message :error, "Could not find push job #{params[:id]}"
      redirect_to :action => :rhn_push_log
      return
    end
  end

  def rpms_for_rhn(errata)

    out = []
    Push::Rhn.rpm_channel_map(errata) do |_, file, *|
      out << file
    end
    out.uniq
  end

  def archives_for_rhn(errata)
    out = []
    Push::Rhn.file_channel_map(errata) do |_, file, *|
      next if file.kind_of?(BrewRpm)
      out << file
    end
    out.uniq
  end

end
