class FixCVEAdvisoryForm < FixAdvisoryForm

  # Errors in fix_cves pub tasks go in here rather than 'errors',
  # because they're considered non-fatal.
  attr_accessor :pub_task_errors

  def initialize(*args)
    self.pub_task_errors = ActiveModel::Errors.new(self)
    super
  end

  def apply_changes
    newcve = params[:errata][:replace_cve]
    oldcve = @errata.content.cve
    @errata.content.cve = newcve

    @changemsg = "CVE names have been changed from:\n#{oldcve}\nto\n#{newcve}"
  end

  def persist!
    self.pub_task_errors.clear

    @errata.content.save

    # Push OVAL and XML to secalert
    return false unless push_to_secalert

    [
      (:rhn_live if @errata.has_rhn_live?),
      (:cdn if @errata.has_cdn?),
    ].compact.each do |target|
      pub_target = Settings.pub_push_targets[target]['target']

      # making a new pub client at each iteration because we tolerate
      # errors, but I'm afraid an error may damage the client
      pc = Push::PubClient.new
      task_id = nil
      begin
        task_id = pc.fix_cve_names(@errata, pub_target, User.current_user)
      rescue StandardError => e
        error = "Pub fix_cves call for #{target} (#{pub_target}) failed: #{e.inspect}"
        Rails.logger.error "#{error}\n#{e.backtrace.join("\n")}"
        pub_task_errors.add(target, error)
        next
      end

      # only newer versions of the API return a task ID - see RCMPROJ-3281
      if task_id
        link = "http://#{Pub::SERVER}#{Pub::PUSH_URL}#{task_id}"
        @changemsg += "\n\nFix CVEs for #{target} pub task: #{link}"
      end
    end

    @errata.comments << CveChangeComment.new(:text => @changemsg)
    @changemsg.gsub!("\n", '<br/>')
  end

end
