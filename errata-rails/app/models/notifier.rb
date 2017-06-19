class Notifier < ActionMailer::Base
  default :from => MAIL['from'],:content_type => 'text/plain'

  # (Include application helper only for pluralize methods)
  helper :notifier, :application

  # Want to add a common footer to all emails so lets use a layout
  # The partner emails don't use the layout
  layout 'notifier', :except => [:partners_new_errata, :partners_changed_files]

  # Header tag constants
  COMPONENT_HEADER  = 'X-ErrataTool-Component'
  ACTION_HEADER     = 'X-ErrataTool-Action'
  REPLY_TO_HEADER   = 'In-Reply-To'
  PREVIOUS_VALUE_HEADER = 'X-ErrataTool-Previous-Value'
  NEW_VALUE_HEADER  = 'X-ErrataTool-New-Value'

  # Necessary to fix an issue where url helpers cannot be
  # invoked in mail, as described in the rails wiki
  # http://wiki.rubyonrails.org/rails/pages/HowtoUseUrlHelpersWithActionMailer/
  helper ActionView::Helpers::UrlHelper

  #
  # We want to avoid errors where we email old users who don't exist any more.
  # Do this to remove any recipients who aren't in the 'can_mailto' scope.
  #
  # (NB: This means we can only email to addresses that have a User record,
  # so remember that any new email recipient needs to have a User record).
  #
  def self.deliver_mail(mail,&block)
    old_list = mail.to
    users_to_mail = User.where(:receives_mail => true, :login_name => mail.to)
    mail.to = users_to_mail.map(&:email)
    if mail.to.empty?
      logger.error "No users in message can receive mail: #{Array.wrap(old_list).join(', ')}"
      return
    end
    # super isn't used because it makes the code hard to test;
    # mocha can't handle the scenario of using the real derived class method
    # but a mocked base class method.
    with_smtp_error_handling{ ActionMailer::Base.deliver_mail(mail,&block) }
  end

  def self.with_smtp_error_handling(&block)
    [1,1,2,3,5,8,nil].each do |delay|
      begin
        return yield
      rescue Net::SMTPFatalError => e
        log_mail_error(e)
        return
      rescue Net::SMTPServerBusy => e
        log_mail_error(e)
        raise e unless delay

        logger.error "Trying again in #{delay} ..."
        sleep delay
      end
    end
  end

  def self.log_mail_error(e)
    logger.error "Error sending mail: #{e.message}"
    logger.error Rails.backtrace_cleaner.clean(e.backtrace)
  end

  #-----------------------------------------------------------------------
  #
  def blocking_issue(issue)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'BLOCKED'
    set_qe_group_header issue.errata
    @issue = issue
    add_recipients issue.notify_target
    add_recipients issue.errata.notify_and_cc_emails
    mail(:to => @recipients,
         :subject => massage_subject("BLOCKED on '#{issue.blocking_role.name}'",issue.errata))
  end

  def info_request(issue)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'INFO_REQUEST'
    set_qe_group_header issue.errata
    @issue = issue
    add_recipients issue.notify_target
    add_recipients issue.errata.notify_and_cc_emails
    mail(:to => @recipients,
         :subject => massage_subject("Info requested of '#{issue.info_role.name}'",issue.errata))
  end

  #-----------------------------------------------------------------------
  # Bugzilla related mail
  #
  def bugs_updatebugstates(comment)
    headers[COMPONENT_HEADER] = 'BUGZILLA'
    headers[ACTION_HEADER] = 'UPDATED'
    mail_with_comment(comment, 'Bug updated')
  end

  def bugs_add_bugs_to_errata(comment)
    headers[COMPONENT_HEADER] = 'BUGZILLA'
    headers[ACTION_HEADER] = 'ADDED'
    mail_with_comment(comment,'Bug added')
  end

  def bugs_remove_bugs_from_errata(comment)
    headers[COMPONENT_HEADER] = 'BUGZILLA'
    headers[ACTION_HEADER] = 'REMOVED'
    mail_with_comment(comment,'Bug removed')
  end

  def jira_issue_added(comment)
    headers[COMPONENT_HEADER] = 'JIRA'
    headers[ACTION_HEADER] = 'ADDED'
    mail_with_comment(comment,'JIRA issue added')
  end

  def jira_issue_removed(comment)
    headers[COMPONENT_HEADER] = 'JIRA'
    headers[ACTION_HEADER] = 'REMOVED'
    mail_with_comment(comment, 'JIRA issue removed')
  end

  #-----------------------------------------------------------------------
  # Documentation related mail
  #
  def docs_approve(comment)
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = 'APPROVED'
    @action = 'APPROVED'
    errata = comment.errata
    add_recipients(errata.content.doc_reviewer.login_name, MAIL['default_docs_user'])
    mail_with_comment(comment,'Docs APPROVED')
  end

  def docs_disapprove(comment)
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = 'DISAPPROVED'
    @action = 'DISAPPROVED'
    errata = comment.errata
    add_recipients(errata.content.doc_reviewer.login_name, MAIL['default_docs_user'])
    mail_with_comment(comment,'Docs DISAPPROVED')
  end

  def docs_ready(errata)
    @action = (errata.text_ready == 1 ? 'READY' : 'NOTREADY')
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = @action
    set_qe_group_header errata
    @errata = errata
    add_recipients(errata.content.doc_reviewer.login_name, MAIL['default_docs_user'])
    mail(:to => @recipients,
         :subject => massage_subject('Text Ready Changed',errata))
  end

  #
  # Notifies when a documentation reviewer gets changed.
  # Used in DocsController#change_reviewer.
  #
  def docs_update_reviewer(errata, old_reviewer=nil)
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = 'REVIEWER-UPDATE'
    headers[REPLY_TO_HEADER] = 'errata-' + errata.fulladvisory + '@redhat.com'
    set_qe_group_header errata
    @errata = errata
    @old_reviewer = old_reviewer

    # Let's send to the old reviewer as well as the new reviewer so they know they have been unassigned.
    add_recipients(errata.content.doc_reviewer.login_name, old_reviewer.login_name, MAIL['default_docs_user'])
    mail(:to => @recipients,
         :subject => massage_subject("#{errata.content.doc_reviewer.realname} assigned to Docs Review",errata))
  end

  def docs_text_changed(errata, textchanges, modified_by)
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = 'TEXT-CHANGED'
    headers[REPLY_TO_HEADER] = 'errata-' + errata.fulladvisory + '@redhat.com'
    set_qe_group_header errata

    @errata = errata
    @textchanges = textchanges
    @modified_by = modified_by.to_s

    set_default_recipients(errata)
    add_recipients(errata.content.doc_reviewer.login_name, MAIL['default_docs_user'])
    mail(:to => @recipients,
         :subject => massage_subject('Docs changed',errata))
  end

  def request_docs_approval(errata)
    headers[COMPONENT_HEADER] = 'DOCUMENTATION'
    headers[ACTION_HEADER] = 'READY'
    set_qe_group_header errata
    add_recipients(errata.content.doc_reviewer.login_name, MAIL['default_docs_user'])
    @errata = errata
    mail(:to => @recipients,
         :subject => massage_subject('Text ready for review',errata))
  end

  def multi_product_to_qe(errata)
    multi_product_notify(errata, :reason => :qe)
  end

  def multi_product_activated(errata)
    multi_product_notify(errata, :reason => :flag)
  end

  #-----------------------------------------------------------------------
  # Not sure if this is ever used
  #
  def management_report(release)
    @release = release
    mail(:to => dev_recipient,
         :subject => "ET: Management Report for release #{release.name}")
  end

  #-----------------------------------------------------------------------
  #
  def file_pub_failure_ticket(job, who)
    @job = job
    mail(:from => who.login_name,
         :to => 'release-engineering@redhat.com',
         :subject => massage_subject("Pub push job #{job.pub_task_id} failed",job.errata))
  end

  def post_push_failed(job)
    @job = job
    mail(:to => job.pushed_by.login_name,
         :subject => massage_subject("#{job.push_target.display_name} post-push tasks failed", job.errata))
  end

  def auto_prepush_failed(job)
    @job = job
    mail(:to => 'release-engineering@redhat.com',
         :subject => massage_subject("Pub pre-push job #{job.pub_task_id} failed", job.errata))
  end

  #-----------------------------------------------------------------------
  #
  def sign_advisory(errata, text, recipients)
    @errata = errata
    @text = text
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'ADVISORY_SIGN-REQUEST'
    set_qe_group_header errata
    add_recipients(*recipients)
    mail(:to => @recipients,
         :subject => massage_subject('Signature requested',errata))
  end

  #-----------------------------------------------------------------------
  # TPS related mail
  #
  def tps_reschedule_all(comment);               mail_for_tps_reschedule(comment, :all=>true); end
  def tps_reschedule_all_rhnqa(comment);         mail_for_tps_reschedule(comment, :all=>true); end
  def tps_reschedule_all_failure(comment);       mail_for_tps_reschedule(comment); end
  def tps_reschedule_all_rhnqa_failure(comment); mail_for_tps_reschedule(comment); end
  def tps_reschedule_job(comment);               mail_for_tps_reschedule(comment); end
  def tps_all_jobs_finished(comment);            mail_tps_jobs_finished (comment); end

  def tps_tps_service(comment)
    errata = comment.errata
    @errata = errata
    headers[COMPONENT_HEADER] = "#{'RHNQA-' if errata.rhnqa == 1}TPS"
    mail_with_comment(comment,'TPS service')
  end

  def tps_waive(comment)
    errata = comment.errata
    @errata = errata
    headers[ACTION_HEADER] = 'WAIVED'
    @waived = true
    headers[COMPONENT_HEADER] = "#{'RHNQA-' if errata.rhnqa == 1}TPS"
    mail_with_comment(comment,'TPS result waived')
  end

  def tps_unwaive(comment)
    errata = comment.errata
    @errata = errata
    headers[ACTION_HEADER] = 'UNWAIVED'
    @waived = false
    headers[COMPONENT_HEADER] = "#{'RHNQA-' if errata.rhnqa == 1}TPS"
    mail_with_comment(comment,'TPS result UN-waived')
  end

  #-----------------------------------------------------------------------
  # RPMDiff related mail
  #
  def rpmdiff_add_comment(comment)
    headers[COMPONENT_HEADER] = 'RPMDIFF'
    headers[ACTION_HEADER] = 'COMMENT'
    mail_with_comment(comment,'RPMDiff comment added')
  end

  def rpmdiff_waive(comment)
    headers[COMPONENT_HEADER] = 'RPMDIFF'
    headers[ACTION_HEADER] = 'WAIVED'
    mail_with_comment(comment,'RPMDiff result waived')
  end

  def rpmdiff_unwaive(comment)
    headers[COMPONENT_HEADER] = 'RPMDIFF'
    headers[ACTION_HEADER] = 'UNWAIVED'
    mail_with_comment(comment,'RPMDiff result UN-waived')
  end

  def rpmdiff_request_waivers(comment)
    headers[COMPONENT_HEADER] = 'RPMDIFF'
    headers[ACTION_HEADER] = 'WAIVED'
    mail_with_comment(comment,'RPMDiff results waived')
  end

  # note this code would have to change if acking waivers also sent an email
  def rpmdiff_ack_waivers(comment)
    headers[COMPONENT_HEADER] = 'RPMDIFF'
    headers[ACTION_HEADER] = 'ACK-UPDATE'
    mail_with_comment(comment,'RPMDiff waiver status updated')
  end

  #-----------------------------------------------------------------------
  #
  def errata_file_request(comment)
    errata = comment.errata
    headers['Message-ID'] = errata.message_id
    add_recipients(errata.quality_responsibility.default_owner.login_name)
    @errata = errata
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'NEW-QA-REQUEST'
    mail_with_comment(comment,'File requested')
  end

  #
  # This one is the default in comment_sweeper.rb
  #
  def errata_update(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'EDIT-QA-REQUEST'
    mail_with_comment(comment,'Updated')
  end

  def errata_state_change(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'STATE-CHANGE'
    headers[PREVIOUS_VALUE_HEADER] = comment.state_index.previous
    headers[NEW_VALUE_HEADER] = comment.state_index.current
    mail_with_comment(comment, 'State Changed')
  end

  def errata_cve_change(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'CVE-CHANGE'
    mail_with_comment(comment, 'CVE Changed')
  end

  def errata_live_id_change(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'LIVE-ID-CHANGE'
    mail_with_comment(comment, 'Live ID Changed')
  end

  def errata_build_signed(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'BUILD-SIGNED'
    mail_with_comment(comment, 'Build Signed')
  end

  def errata_signatures_requested(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'SIGNATURES-REQUESTED'
    mail_with_comment(comment, 'Signatures Requested')
  end

  def errata_signatures_revoked(comment)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'SIGNATURES-REVOKED'
    mail_with_comment(comment, 'Signatures Revoked')
  end

  #-----------------------------------------------------------------------
  #
  def errata_request_signatures(errata)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'SIGN-REQUEST'
    set_qe_group_header errata
    @errata = errata
    mail(:to => Role.signers.map(&:login_name),
         :subject => massage_subject("Package signature request",errata))
  end

  def request_translation(errata, text)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'PUBLISHED'
    set_qe_group_header errata
    @text = text
    @errata = errata
    mail(:to => ['security-response-team@redhat.com', 'gss-china-list@redhat.com'],
         :subject => massage_subject("Translation request #{errata.advisory_name}-#{errata.pushcount}",errata))
  end

  # This is used for all advisories regardless of if they are pushed
  # to CDN, RHN or both, hence the method name is not a good one
  def request_rhnlive_push(errata)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'PUSH-REQUEST'
    set_qe_group_header errata

    # Batches should go to rel-eng exclusively, even if RHSA (bug 1279905)
    # ET no longer sends notification to security-response@ (bug 1305500)
    contact = 'release-engineering@redhat.com' unless errata.is_security? && errata.batch.nil?

    list = [contact, errata.assigned_to.login_name, errata.reporter.login_name].compact
    list << errata.package_owner.login_name if errata.package_owner != errata.assigned_to
    @errata = errata
    mail(:to => list,
         :subject => massage_subject("Live push request #{errata.advisory_name}-#{errata.pushcount}",errata))
  end

  def request_rcm_rhsa_push(errata)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'PUSH-REQUEST'
    set_qe_group_header errata
    contact = 'release-engineering@redhat.com'
    list = [contact, errata.assigned_to.login_name, errata.reporter.login_name]
    list << errata.package_owner.login_name if errata.package_owner != errata.assigned_to
    @errata = errata
    @user = User.current_user
    mail(:to => list,
         :subject => massage_subject("RHSA push request", errata))
  end

  #-----------------------------------------------------------------------
  # Send notification email to security-response@redhat.com if user not in
  # Product Security successfully completed the push of an RHSA.
  # See https://bugzilla.redhat.com/show_bug.cgi?id=1286790
  def rhsa_shipped_live(errata, pushed_by)
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'SHIPPED_LIVE'
    @errata = errata
    @pushed_by = pushed_by
    mail(:to => 'security-response@redhat.com',
         :subject => massage_subject("Shipped Live", errata))
  end

  #-----------------------------------------------------------------------
  # For partner emails keep the old style subject in case the partners have filters on it
  # Also note that these two emails don't use the layout.
  #
  # If we ever to want to change them to the new format it might look like this:
  #  massage_subject("Available for partner testing",errata)
  #  massage_subject("New files",errata)
  #
  def partners_new_errata(errata)
    @errata = errata
    headers['Reply-To'] = 'partner-reporting@redhat.com'
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'NEW-QA-REQUEST'
    mail(:to => 'partner-testing@redhat.com',
         :subject => "Errata Request #{errata.advisory_name} - #{errata.synopsis} is now available for partner testing.") do |format|
      format.text {render :layout => false}
    end
  end

  def partners_changed_files(errata)
    @errata = errata
    headers['Reply-To'] = 'partner-reporting@redhat.com'
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'CHANGED-FILES'
    mail(:to => 'partner-testing@redhat.com',
         :subject => "Errata Request #{errata.advisory_name} - #{errata.synopsis} has new files.") do |format|
      format.text {render :layout => false}
    end
  end

  #-----------------------------------------------------------------------
  # Notifies a user when their roles get changed (or they get disabled)
  def user_roles_change(changed,changed_by,change_details)
    # I've made these up just now. Not sure if it's important.
    headers[COMPONENT_HEADER] = 'ADMIN'
    headers[ACTION_HEADER] = 'USER-ROLES'

    @changed        = changed
    @changed_by     = changed_by
    @change_details = change_details

    mail(:to      => @changed.login_name,
         #:cc      => @changed_by.login_name, # Not sure if this is desirable. Maybe CC some other email??
         :subject => massage_subject("User roles changed for #{@changed}"))
  end

  def job_tracker_completed(tracker)
    @tracker = tracker
    mail(:to => tracker.user.login_name, :subject => "Job Completed: #{tracker.name}")
  end

  def job_tracker_failed(tracker)
    @tracker = tracker
    mail(:to => tracker.user.login_name, :subject => "Job Failed: #{tracker.name}")
  end

  #-----------------------------------------------------------------------
  #
  def dummy(message='Hello')
    # Ensure we don't send these out by mistake:
    raise 'This is only for the development environment' unless Rails.env.development?
    @message = message
    mail(:to => dev_recipient,
         :subject => massage_subject('Dummy Test Email'))
  end

  private

  # Shared by a bunch of tps reschedule emails
  def mail_for_tps_reschedule(comment, opts={})
    @errata = comment.errata
    # (Not sure why this message is necessary but keeping it in case it is important)
    @message = "Rescheduled all #{'RHNQA ' if @errata.rhnqa == 1}TPS jobs" if opts[:all]
    headers[ACTION_HEADER] = 'RESCHEDULED'
    headers[COMPONENT_HEADER] = "#{'RHNQA-' if @errata.rhnqa == 1}TPS"
    mail_with_comment(comment, 'TPS rescheduled')
  end

  def mail_tps_jobs_finished(comment)
    @errata = comment.errata
    headers[ACTION_HEADER] = 'TPS_RUNS_COMPLETE'
    headers[COMPONENT_HEADER] = "#{'RHNQA-' if @errata.rhnqa == 1}TPS"
    mail_with_comment(comment, 'TPS runs complete')
  end

  # Several emails use a similar format which is defined here
  def mail_with_comment(comment,subject='')
    errata = comment.errata
    set_qe_group_header errata
    set_who_header_for_comment comment
    set_default_recipients(errata)

    # TODO: Change message workflow here
    if errata.status == State::NEW_FILES
      unless  headers['Message-ID']
         headers['In-Reply-To'] = errata.message_id
         headers['References'] = errata.message_id
      end
    else
       headers['In-Reply-To'] = errata.message_id
       headers['References'] = errata.message_id
    end
    @comment = comment
    mail(:to => @recipients,
         :subject => massage_subject(subject,errata))
  end

  # Notify users that a multi-product advisory is available.
  # Args can contain:
  #   :reason => The reason why this mail is being sent.
  #              Either :qe   (multi-product advisory moved to QE)
  #                  or :flag (multi-product flag moved from false to true)
  #
  def multi_product_notify(errata, args={})
    headers[COMPONENT_HEADER] = 'ERRATA'
    headers[ACTION_HEADER] = 'MULTI-PRODUCT-ACTIVATED'
    subject = "Multi-product advisory is available"

    @errata = errata
    @reason = args.fetch(:reason, :flag)
    @mapped_products = []
    @mapped_packages = Hash.new do |h, k|
      h[k] = HashList.new
    end

    mapping_activated = lambda do |mapping|
      add_recipients(*mapping.subscribers.map(&:login_name))

      dist    = mapping.destination
      product = dist.product_version.product
      package = mapping.package

      (@mapped_products << product).uniq!
      (@mapped_packages[package][product] << dist).uniq!
    end

    # We do not care about the file channel/repo map itself, only the
    # activated multi-product mapping rules.
    options = {
      :on_multi_product_mapped => mapping_activated,
    }
    do_nothing = lambda{ |*args| }

    Push::Rhn.file_channel_map(@errata, options, &do_nothing)
    Push::Cdn.file_repo_map(@errata, options, &do_nothing)

    if @recipients.blank?
      logger.info "Nobody to notify for multi-product advisory #{errata.id}."
      return
    end

    mail(:to => @recipients,
         :subject => massage_subject(subject, errata))
  end

  def set_default_recipients(errata)
    add_recipients(errata.notify_and_cc_emails)
    add_recipients(MAIL['default_qa_user'])
    add_recipients(MAIL['default_security_user']) if errata.is_security?
  end

  def set_qe_group_header(errata)
    headers['X-Errata-QE-Group'] = errata.quality_responsibility.name
  end

  def set_who_header_for_comment(comment)
    set_who_header(comment.try(:who))
  end

  def set_who_header(user)
    headers['X-ErrataTool-Who'] = user.try(:login_name)
  end

  def add_recipients(*people)
    @recipients ||= []
    @recipients.concat(people.flatten)
    @recipients.uniq!
  end

  # See bugs 678350 and 462852
  def massage_subject(subject='',errata=nil)
    "ET: #{"#{errata.name_release_and_short_title}" if errata}#{"#{' - ' if errata}#{subject}" if !subject.blank?}"
  end

  def dev_recipient
    MAIL['dev_recipient']
  end
end
