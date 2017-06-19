class FtpPushJob < PushJob
  # TODO
  POST_PUSH_TASKS = {
    'mark_ftp_done' => {
      :description => "Mark errata having ftp files pushed.",
      :mandatory   => true,
    }
  }

  def can_push?
    return false unless super
    self.no_missing_files?
  end

  def validate_can_push?
    super
    errors.add_to_base(self.missing_files_message) if self.missing_files?
  end

  def valid_post_push_tasks
    POST_PUSH_TASKS
  end

  def push_details
    res = Hash.new
    res['should'] = errata.has_ftp?
    res['can'] = errata.can_push_ftp?
    res['blockers'] = errata.push_ftp_blockers
    res['target'] = target
    res
  end

  def default_push_type; :ftp; end

  protected

  #
  # Returns true if all files are found (true indicates success)
  #
  def no_missing_files?
    self.files_missing.empty?
  end

  #
  # Returns true if there are any missing files (true indicates an error).
  #
  def missing_files?
    !self.no_missing_files?
  end

  #
  # Make an error message showing which files are missing. (Bug 710026).
  #
  def missing_files_message
    "These files were not found (and might need to be reconstructed by Brew):<ul><li>#{self.files_missing.join("</li><li>")}</li></ul>"
  end

  #
  # Returns an array of the missing files (an empty array if none are missing).
  #
  def files_missing
    # Use an instance var to cache the result so it only hits the filesystem once
    @files_missing_cached ||= Push::Ftp.errata_files_missing(self.errata)
  end

  def task_mark_ftp_done
    errata.pushed = 1
    errata.save
  end
end
