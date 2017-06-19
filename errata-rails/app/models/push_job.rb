=begin
CREATE TABLE `push_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `errata_id` int(11) NOT NULL,
  `pushed_by` int(11) NOT NULL,
  `push_type` varchar(10) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'READY',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `log` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `errata_id` (`errata_id`),
  KEY `pushed_by` (`pushed_by`),
  CONSTRAINT `rhn_push_jobs_ibfk_1` FOREIGN KEY (`errata_id`) REFERENCES `errata_main` (`id`),
  CONSTRAINT `rhn_push_jobs_ibfk_2` FOREIGN KEY (`pushed_by`) REFERENCES `users` (`id`)
)
=end

class PushJob < ActiveRecord::Base
  include ModelChild

  belongs_to :errata,
    :class_name => "Errata",
    :foreign_key => 'errata_id'

  belongs_to :pushed_by,
    :class_name => "User",
    :foreign_key => "pushed_by"

  belongs_to :push_target

  serialize :pub_options, Hash
  serialize :pre_push_tasks, Array
  serialize :post_push_tasks, Array

  validates_presence_of :errata, :pushed_by, :push_target
  validate :no_duplicate_jobs

  validate(:on => :create) do
    validate_can_push?
    validate_tasks?
    validate_pub_options?
    validate_nochannel_tasks
  end

  # TODO
  #validate_inclusion_of :status,
  #  :in => ['READY', 'RUNNING','QUEUED','WAITING_ON_PUB','COMPLETE','FAILED']

  ACTIVE_STATUS = ['RUNNING','READY','QUEUED','WAITING_ON_PUB']

  scope :jobs_waiting_on_pub, :conditions => "status = 'WAITING_ON_PUB'"
  scope :active_jobs, where(:status => ACTIVE_STATUS)

  scope :for_errata, lambda { |errata| { :conditions => ["errata_id = ?", errata] } }
  scope :for_pub_task, (lambda do |pub_task_id|
    { :conditions => {:pub_task_id => pub_task_id} }
  end)

  scope :nochannel,
        :conditions => 'pub_options like "%\nnochannel: true\n%"'

  scope :excluding_nochannel,
        :conditions => 'pub_options not like "%\nnochannel: true\n%"'

  def can_push?(type = nil)
    type ||= push_type
    errata.send("can_push_#{type}?", pub_options)
  end

  def validate_can_push?(type = nil)
    type ||= push_type
    unless errata.send("can_push_#{type}?", pub_options)
      push_blockers(type).each { |b| errors.add(:base, b) }
    end
    if !type.to_s.include?("stage") && !pushed_by.in_role?('pusherrata')
      errors.add(:pushed_by, "User #{pushed_by.to_s} is not in pusherrata role")
    end
  end

  def push_blockers(type = nil)
    type ||= push_type
    errata.send("push_#{type}_blockers", pub_options)
  end

  after_initialize do
    return unless self.new_record?
    self.pre_push_tasks ||= []
    self.post_push_tasks ||= []
    self.pub_options ||= {}
  end

  before_validation(:on => :create) do
    self.push_target = errata.push_target_for_push_type(push_type)
  end

  before_create do
    self.priority = default_priority unless self.priority > 0
    unless self.pub_options.has_key?('priority')
      self.pub_options['priority'] = self.priority
    end
    unless is_nochannel?
      self.pre_push_tasks.concat(valid_pre_push_tasks.select {|k,v| v[:mandatory]}.collect {|v| v.first}).uniq!
      self.post_push_tasks.concat(valid_post_push_tasks.select {|k,v| v[:mandatory]}.collect {|v| v.first}).uniq!
    end
  end

  def create_pub_task(pub)
    raise "The advisory does not support pushes to #{self.push_type} at this time" unless can_push?
    raise "Advisory is flagged to skip pub and only run post push tasks" if skip_pub_task_and_post_process_only?

    new_task_id = nil
    begin
      run_pre_push_tasks
      new_task_id = pub.submit_push_job(self)
      unless new_task_id
        raise 'Unable to get a task id from Pub; submission failed'
      end
    rescue => e
      mark_as_failed! e.message
      raise e
    end

    set_pub_task new_task_id
    self.class.ensure_watcher
    return true
  end

  def set_pub_task(new_task_id)
    self.pub_task_id = new_task_id
    self.status = 'WAITING_ON_PUB'
    save(:validate=>false)
    info "Pub task created, task id: #{new_task_id}"
    if is_nochannel?
      info 'Note: this is a nochannel push.'
    end
    info "Link to the pub task: http://#{Pub::SERVER}#{Pub::PUSH_URL}#{new_task_id}"
    info "Waiting on pub to finish."
  end

  def self.create_multipush_pub_task(pub, push_jobs)
    return if push_jobs.empty?

    # Make sure log mentions this was a multipush
    errata_ids = push_jobs.map(&:errata_id).sort
    message = "Multipush, submitting #{errata_ids.length} errata: " +
              errata_ids.join(', ').truncate(100)
    push_jobs.each do |job|
      job.send(:append_to_log, message)
    end

    new_task_id = nil
    begin
      new_task_id = pub.submit_multipush_jobs(push_jobs)
      unless new_task_id
        raise 'Unable to get a task id from Pub; submission failed'
      end
    rescue => e
      push_jobs.each do |job|
        job.mark_as_failed! e.message
      end
      raise e
    end

    push_jobs.each do |job|
      job.set_pub_task new_task_id
    end

    ensure_watcher
  end

  # Submits the job for execution.  Call this after setting options and pre/post-push tasks.
  # Usually creates a pub task, but may decide not to in some cases.
  #
  # If a :pub_submit block is given, it is called with this job to submit to pub.
  # Otherwise, the create_pub_task method is used.
  def submit!(opts={})
    trace = opts[:trace] || lambda{|msg| Rails.logger.info(msg)}

    name = self.class.model_name.human

    pub_submit = opts[:pub_submit] || lambda do |_|
      self.create_pub_task(Push::PubClient.get_connection)
      trace.call("#{name} submitted to pub; pub task id is <a href='http://#{Pub::SERVER}#{Pub::PUSH_URL}#{self.pub_task_id}'>#{self.pub_task_id}</a>")
    end

    if self.skip_pub_task_and_post_process_only?
      self.start_post_push_processing!(true)
      trace.call("#{name} skipping pub; running post-push tasks only: #{self.post_push_tasks.join(', ')}")
    else
      pub_submit[self]
    end
  end

  # submit to pub, but only if the status is READY.
  #
  # This is intended for use from delayed jobs, where the push job could have
  # been cancelled before it was submitted to pub.
  def submit_if_ready!(opts={})
    if status != 'READY'
      warn "Not submitting to pub because status is #{status}."
      return
    end

    blockers = push_blockers
    unless blockers.empty?
      # If we are ready but can no longer push, the job should be abandoned.
      msg = 'Cancelling, errata no longer eligible for push: '
      msg += blockers.join(', ')
      mark_as_failed! msg
      return
    end

    submit! opts
  end

  # Submit a collection of push jobs to pub as a single pub task.
  #
  # All push jobs must be of the same target, and that pub target must support
  # multipush (it's the caller's responsibility to check that).
  #
  # Tasks-only jobs, jobs in the wrong status or jobs where pre-push tasks fail
  # will be filtered out before submitting to pub.
  def self.submit_multipush(push_job_ids)
    push_jobs = PushJob.includes(:push_target).where(:id => push_job_ids).lock
    return if push_jobs.empty?

    targets = push_jobs.map(&:push_target).map(&:name).uniq.sort
    if targets.length != 1
      raise ArgumentError.new("Attempt to submit multipush for mixed targets #{targets.inspect}")
    end

    to_submit = []
    collector = lambda do |job|
      to_submit << job
    end

    push_jobs.each do |push_job|
      push_job.submit_if_ready!(:pub_submit => collector)
    end

    # to_submit now has removed not-ready or post-process-only jobs.

    # Run pre-push tasks for all jobs (ignore jobs where the tasks failed)
    to_submit = to_submit.select(&:try_run_pre_push_tasks)

    # to_submit now contains only those jobs which should really be submitted.

    create_multipush_pub_task(Push::PubClient.get_connection, to_submit)
  end

  def submit_later
    self.send_prioritized(50, :submit_if_ready!)
  end

  def self.submit_multipush_later(push_jobs)
    self.send_prioritized(50, :submit_multipush, push_jobs.map(&:id))
  end

  def in_queue?
    self.status == 'QUEUED'
  end

  def is_finished?
    ['COMPLETE', 'FAILED'].include?(self.status)
  end

  def is_waiting?
    self.status == 'WAITING_ON_PUB'
  end

  # Returns true if this is a "nochannel" push, meaning that the push job does
  # not attach packages to channels/repos, thus does not make an update
  # visible to customers.
  #
  # These jobs are treated specially in certain contexts, since the presence
  # of a completed job doesn't imply that an update is shipped if that job is
  # nochannel.
  def is_nochannel?
    self.pub_options['nochannel']
  end

  def in_progress?
    ACTIVE_STATUS.include?(self.status)
  end

  def post_push_processing?
    self.status == 'POST_PUSH_PROCESSING'
  end

  def failed?
    self.status == 'FAILED'
  end

  #
  # Not active anymore. The push has completed or is almost complete.
  #
  def is_committed?
    ['COMPLETE', 'POST_PUSH_PROCESSING', 'POST_PUSH_FAILED'].include?(self.status)
  end

  def mark_as_complete!
    self.status = 'COMPLETE'
    info "Completed Successfully"
    save!
  end

  def mark_as_failed!(msg)
    return if 'FAILED' == self.status
    self.status = 'FAILED'
    error msg
    save!
    # reload to make sure we don't keep the wrong setting in memory
    # e.g. if the wrong state index was set, we need to clear it.
    self.errata.reload
    # check if there is any live job running. If not then move
    # the errata status to REL_PREP
    task_check_error if self.respond_to?(:task_check_error)
  end

  def mark_as_running!
    self.status = 'RUNNING'
    save!
  end

  def push_user_name
    pushed_by.login_name
  end

  def errata_pub_name
    errata.advisory_name
  end

  # implemented in subclasses
  def push_details
    raise NotImplementedError
  end

  def push_type
    self.class.to_s.gsub('PushJob','').underscore.to_sym
  end

  def target
    push_target ||= errata.push_target_for_push_type(push_type)
    push_target.pub_target
  end

  def set_defaults
    self.pre_push_tasks = self.valid_pre_push_tasks.select {|k,v| v[:default] || v[:mandatory]}.collect {|v| v.first}
    self.post_push_tasks = self.valid_post_push_tasks.select {|k,v| v[:default] || v[:mandatory]}.collect {|v| v.first}
    self.pub_options = self.valid_pub_options.select {|k,v| v[:default]}.inject({}) { |h, (k, v)| h[k] = true; h }
  end

  def skip_pub_task_and_post_process_only?
    false
  end

  def pub_success!(args={})
    info "Pub completed."
    start_post_push_processing!(args.fetch(:process_later, false))
  end

  def start_post_push_processing!(process_later = false)
    self.status = 'POST_PUSH_PROCESSING'

    # check if there is any available post push task to run
    all_tasks = post_push_tasks
    task_defs = valid_post_push_tasks

    tasks = all_tasks.select do |t|
      av = task_availability(t, task_defs[t] || {})
      unless av.available?
        # For any task not scheduled, leave a message explaining why.
        info "Skipping task #{t}: #{av.reason}"
      end
      av.available?
    end

    # Don't need to schedule any delayed job if there is no available task to run
    return self.mark_as_complete! if tasks.empty?

    if process_later
      ActiveRecord::Base.transaction do
        # The number of available tasks to be run can be affected by the related push
        # jobs if more than 1 delayed job workers working at the same time. Therefore,
        # it is better to determine what tasks need to be run while scheduling the
        # delayed jobs.
        job = self.send_prioritized(7, :run_post_push_tasks, tasks)
        info "Running post push tasks in background job #{job.id}."
        save!
      end
    else
      info "Running post push tasks."
      save!
      run_post_push_tasks(tasks)
    end
  end

  def can_enqueue?
    false
  end

  def default_priority
    # Base value is:
    # (pub CLI default = 10) + (10 for "live") + 2
    # See: https://bugzilla.redhat.com/show_bug.cgi?id=1304780#c0
    out = 22

    # RHSA more important than other types
    out += 5 if errata.is_security?

    # nochannel is an optimization step, pub should not work on it when there are regular
    # pushes waiting
    out -= 10 if is_nochannel?

    out
  end

  # Returns the most recent push job of this type, excluding certain types of
  # jobs which do not count towards whether an advisory is considered "pushed",
  # such as nochannel jobs.
  def self.last_push(errata)
    self.excluding_nochannel.find(:last,
                      :conditions =>
                      ["errata_id = ?", errata],
                      :order => 'updated_at asc')
  end

  def cancel!(pub, canceled_by)
    return false if is_finished?
    if status == 'WAITING_ON_PUB' and pub_task_id?
      logger.debug "Trying to cancel pub push job."
      begin
        pub.cancel_task(pub_task_id)
        info("Pub task cancelled")
      rescue XMLRPC::FaultException => e
        logger.debug "fCode: #{e.faultCode}"
        logger.debug "fString: #{e.faultString}"
        warn("Pub task could not be cancelled")
      rescue StandardError => e
        logger.debug "Exception: #{e}"
        warn("Pub task could not be cancelled")
      end
    end
    mark_as_failed! "Push job stopped on behalf of user #{canceled_by.login_name}"
    true
  end


  def all_valid_tasks
    valid_pre_push_tasks.merge(valid_post_push_tasks)
  end

  def all_valid_optional_tasks
    all_valid_tasks.reject{ |n,t| t[:mandatory]}
  end

  def valid_pub_option_keys
    valid_pub_options.keys.push('priority').uniq
  end

  #######################################################################
  # This next block of methods are expected to be overriden by subclasses
  # to implement task/option logic specific to each push type.

  def valid_pub_options
    { }
  end

  def valid_pre_push_tasks
    { }
  end

  def valid_post_push_tasks
    { }
  end

  def task_availability(task_name, task_def)
    Available.new
  end

  #######################################################################

  def available_tasks(task_names, task_defs)
    task_names.select do |task_name|
      task_available?(task_name, task_defs.fetch(task_name, {}))
    end
  end

  def available_post_push_tasks
    available_tasks post_push_tasks, valid_post_push_tasks
  end

  def task_available?(task_name, task_def)
    task_availability(task_name, task_def).available?
  end

  def info(msg)
    logger.info msg
    append_to_log msg
  end

  def warn(msg)
    logger.warn msg
    append_to_log msg
  end

  def error(msg)
    logger.error msg
    append_to_log msg
  end

  def self.valid_push_types
    # Beware: descendants method doesn't know about subclasses that aren't yet loaded
    PushJob.descendants.collect {|t| t.to_s.gsub('PushJob','').underscore.to_sym}
  end

  # Returns a PushJob of this type that is still valid and running. Excludes certain
  # types of jobs which do not count towards overall success/fail of push.
  def self.active_job_for(errata)
    active_jobs.excluding_nochannel.for_errata(errata).first
  end

  # Queues submission of a collection of push +jobs+.
  #
  # Compared to simply calling +submit_later+ on each job, this method may be
  # able to coalesce some jobs into a single pub task (multipush), which can
  # give significant performance benefits.
  #
  # Jobs must have the same target and pub_options to be pushed together
  # using multipush.
  def self.submit_jobs_later(jobs)
    pub = Push::PubClient.get_connection
    jobs.group_by{|j| [j.push_target, j.pub_options.except('priority')]}.each do |(push_target, _), these_jobs|
      # Pub server itself claims multipush support is globally present or
      # absent, i.e. not per each target.  We support overriding per target
      # because in practice it seems that target-specific multipush issues could
      # arise.
      do_multipush   = these_jobs.length > 1
      do_multipush &&= push_target.supports_multipush?
      do_multipush &&= pub.supports_multipush?
      if do_multipush
        submit_multipush_later(these_jobs)
      else
        these_jobs.each(&:submit_later)
      end
    end
  end

  def run_pre_push_tasks
    info "Running pre push tasks"
    begin
      pre_push_tasks.each do |t|
        info "Running pre push task #{t}"
        run_task(t)
      end
    rescue => e
      mark_as_failed! "Pre push errors: #{e.message}"
      raise e
    end
  end

  # Like run_pre_push_tasks, but does not raise on error.
  # Returns true if tasks ran successfully.
  def try_run_pre_push_tasks
    run_pre_push_tasks
    true
  rescue => e
    # Don't need to do anything with the error here.
    # It was already logged in run_pre_push_tasks.
    false
  end

  def run_post_push_tasks(tasks = nil)
    unless post_push_processing?
      info "Post-push tasks not run because job status is #{status}."
      return
    end

    tasks_to_be_run = Array.wrap(tasks)
    # process dependencies, possibly filtering out some tasks
    tasks_to_be_run = available_tasks(post_push_tasks, valid_post_push_tasks) if tasks_to_be_run.empty?

    # Separate mandatory versus optional tasks, run mandatory first
    info "Running post push tasks: #{tasks_to_be_run.join(', ')}"
    mandatory, remainder = tasks_to_be_run.partition {|t| valid_post_push_tasks[t][:mandatory]}
    begin
      info "Running mandatory tasks #{mandatory.join(', ')}"
      (mandatory_complete, cancelled) = run_tasks_helper(mandatory, :run_task)
      return if cancelled

      info "Running remainder: #{remainder.join(', ')}"
      (remainder_complete, cancelled) = run_tasks_helper(remainder, :run_task_ok?)
    rescue Exception => e
      backtrace = e.backtrace.join("\n")
      error "Post push processing stopped. Error running tasks: #{e.message}\n#{backtrace}"
      # re-raise on timeouts and any other non-standard error
      raise e if e.is_a?(Timeout::Error) || !e.is_a?(StandardError)
    ensure
      if cancelled
        info "Post-push processing was interrupted."
      elsif not mandatory_complete
        # If the mandatory tasks didn't complete, the push job status remains IN_PUSH.
        # The push is considered still in progress until a superuser investigates
        # and resolves the issue.
        error 'Mandatory post push tasks incomplete. Not marking job as completed'
      elsif not remainder_complete
        # If non-mandatory tasks didn't complete, the push job is considered
        # "completed, with warnings".  The user who triggered the push is
        # notified and can decide the appropriate actions.
        #
        # Most ET logic considers such a push as "finished", i.e. these errors
        # are intentionally non-blocking.
        warn 'Post push tasks partially complete'
        self.status = 'POST_PUSH_FAILED'
      else
        info 'Post push tasks complete'
        self.status = 'COMPLETE'
      end
      self.save
    end
  end

  def run_task_ok?(t)
    run_task(t)
  rescue
    false
  end

  def run_task(t)
    info "Running task #{t}"
    begin
      methodname = "task_#{t}"
      self.method(methodname).call
    rescue Exception => e
      backtrace = e.backtrace.join("\n")
      error "Error running task #{t}: #{e.class} #{e.message}\n#{backtrace}"
      raise e
    end
    true
  end

  protected

  def reschedule_tps_jobs(type)
    return unless errata.requires_tps?
    # false means don't reschedule jobs if TPS is in manual
    # mode. Simply change the state to NOT_SCHEDULE, so that
    # user can schedule each job manually.
    errata.tps_run.send("reschedule_#{type}_jobs!", false)
    true
  end

  private

  def validate_tasks?
    self.pre_push_tasks.sort.each do |task|
      errors.add(:base, "Task '#{task}' is not a valid task for this push job") unless valid_pre_push_tasks.include?(task)
    end

    self.post_push_tasks.sort.each do |task|
      errors.add(:base, "Task '#{task}' is not a valid task for this push job") unless valid_post_push_tasks.include?(task)
    end
  end

  def validate_pub_options?
    pub_options.keys.sort.each do |option|
      errors.add(:options, "Option '#{option}' is not a valid option for this push job") unless valid_pub_option_keys.include? option
    end
  end

  def validate_nochannel_tasks
    return unless is_nochannel?

    # None of the existing pre/post push tasks make sense for a nochannel push,
    # so make sure they're not selected
    [:pre_push_tasks, :post_push_tasks].each do |task_sym|
      if send(task_sym).present?
        errors.add(task_sym, 'must be empty for nochannel push')
      end
    end

    # It does not make sense to skip pub if this is a nochannel push
    if skip_pub_task_and_post_process_only?
      errors.add(:options, 'cannot use nochannel with tasks-only push')
    end
  end

  def no_duplicate_jobs
    return unless new_record?
    dup = self.class.active_job_for self.errata
    return unless dup
    errors.add(:base, "There already is a running job (id #{dup.id}) for this errata.")
  end

  def append_to_log(msg)
    ts = Time.now.to_s(:Ymdhmsz)
    append = "\n#{ts} #{msg}"
    if self.new_record?
      self.log += append
      return
    end

    # Update log directly in the database.  There are two reasons to
    # do it this way rather than simply updating self.log...
    #
    # (1) We would like log messages to be flushed immediately rather
    # than waiting for a call to save!, because that call might never
    # happen, e.g. if the thread is interrupted.
    #
    # (2) In the case of concurrency, this will correctly retain log
    # messages from multiple threads, rather than the job who saves
    # last overwriting other jobs.  Concurrency is not intentionally
    # used, but has happened accidentally (bug 1198996).
    begin
      PushJob.where(:id => self).update_all(
        ['log = concat(log, ?)', append])
    rescue Exception => e
      backtrace = e.backtrace.join("\n")
      # Don't bother repeating the message content which couldn't be
      # logged, as we've just recently logged it.
      logger.error "Failed to add log message to push job #{self.id}: #{e.message}\n#{backtrace}"
      raise
    end

    # Now reload the updated log (but not other attributes!) in case
    # the value is going to be later used in this thread
    self.log = PushJob.select(:log).find(self).log
  end


  def self.ensure_watcher
    Delayed::Job.enqueue_once Push::PubWatcher.new, 10
  end

  # Returns (all_successful, cancelled)
  # If cancelled is true, execution of tasks stopped midway due to a state change.
  def run_tasks_helper(tasks, method_sym)
    task_status = proc do |t|
      # NOTE: returns out of this method since this is a proc
      return [false, true] unless reload.post_push_processing?

      send(method_sym, t)
    end
    [tasks.map(&task_status).all?, false]
  end
end
