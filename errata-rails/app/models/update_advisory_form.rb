class UpdateAdvisoryForm < AdvisoryForm
  validate :bugs_have_correct_flags, :user_can_change_cve, :user_can_change_release

  attr_reader :request_docs_approval_after_persist

  def initialize(who, form_params = {})
    super(who, form_params)
    unless self.bugs
      self.bugs = BugList.new(errata.bugs.map(&:id).join(' '), errata)
      self.jira_issues = JiraIssueList.new(errata.unambiguous_jira_keys.join(' '), errata)
      [self.bugs, self.jira_issues].each(&:fetch)
    end
  end

  def new_record?
    false
  end

  def set_advisory
    id = @params[:id]
    self.errata = Errata.find_by_advisory id
  end

  def update_attributes
    #
    # Merge existing values from the advisory with given parameters.
    # This way we overwrite existing values given by the user, but don't
    # choke on non-existing values in the request parameters.
    #
    ap = self.class.errata_to_params(self.errata)
    ap.deep_merge! @params.deep_symbolize_keys
    self.params = ap
    super

    # Get the value of the 'Request docs approval' checkbox on the preview page
    set_request_docs_approval_after_persist_from_params

    # When changing the advisory type from RHSA, the reference and the cve fields
    # get modified and cleared respectively by model callbacks on save.
    # When showing the preview the errata is not yet saved, so the callbacks haven't
    # happened yet, hence we need these two hacks so the preview is correct.
    if errata.errata_type_changed?
      content.cve = (errata.is_security? ? content.cve : '')
      content.reference = content.massage_reference(content.reference, errata.errata_type, errata.security_impact)
    end
  end

  def set_request_docs_approval_after_persist_from_params
    @request_docs_approval_after_persist = params[:advisory][:request_docs_approval_after_persist].to_bool if params[:advisory]
  end

  def persist!
    super
    self.errata = Errata.find errata.id
    notify_docs_changes diffs

    # If the user checked "Request docs approval" on the preview page then do that now
    errata.request_docs_approval! if docs_have_changed? && request_docs_approval_after_persist
  end

  def change_docs_reviewer(user_id, comment=nil)
    old_reviewer = @errata.content.doc_reviewer
    new_reviewer = User.find_by_id(user_id)
    return if new_reviewer.nil? || old_reviewer == new_reviewer

    msg = "Changed docs reviewer from #{old_reviewer.to_s} to #{new_reviewer.to_s}"
    Errata.transaction do
      @errata.content.update_attributes({:doc_reviewer => new_reviewer})
      @errata.comments.create(:who => @user, :text => "#{msg}\n#{comment}")
    end
    msg
  end

  def unprivileged_security_field_problems
    # if the type of the advisory is being changed to RHSA, validate the fields as being
    # newly set.  Otherwise, validate that they can't be changed.
    if errata.errata_type_changed? && errata.is_security?
      return super
    end

    out = HashList.new

    [[errata.embargo_date_changed?, 'Embargo Date'],
     [errata.security_impact_changed?, 'Security impact']]\
    .each do |changed,label|
      if changed
        out[label] << "cannot be modified on RHSA by non-secalert users."
      end
    end

    out
  end

  private

  def bugs_have_correct_flags
    return unless errata.group_id_changed?
    # Check if change in release ok given flag requirements
    problems = errata.bugs.reject {|b| release.has_correct_flags? b}
    return unless problems.any?
    errors.add(:idsfixed, "Bugs do not have flags #{release.blocker_flags.join(',')} for release #{release.name}: #{problems.map(&:id).join(', ')}")
  end

  def user_can_change_cve
    return unless errata.content.cve_changed?
    return if who.can_modify_cve?(errata)
    errors.add(:cve, "Only Secalert or kernel developers can add or remove CVEs in an advisory")
  end

  def user_can_change_release
    return unless errata.group_id_changed?
    return if can_change_release?
    errors.add(:release, "#{who.to_s} does not have permission to change the release of this advisory")
  end

  #
  # Added the second argument to make a diff that shows the original
  # values. See Bz 737706.
  #
  def diff_edits(diff_from_empty=false)
    edit_diffs = Hash.new
    e = Errata.find(errata.id)

    # synopsis field needs a special case due to being rewritten before save...
    get_errata = {
      :synopsis => lambda { |e,_| synopsis_preview(e) },
      :default => lambda { |e,field| e.send(field) }
    }
    get_params = {
      :synopsis => lambda { |_| synopsis_preview_from_params },
      :default => lambda { |field| params[:advisory][field] }
    }

    # NOTE: Not sure why only these fields are checked, other
    # changes like keywords, cross_references, idsfixed etc might
    # also cause the docs output to change. Is this a feature?
    [:synopsis, :topic, :description, :solution].each do |field|
      errata_read = get_errata[field] || get_errata[:default]
      params_read = get_params[field] || get_params[:default]
      if diff_from_empty
        # This part is a little confusing.
        # Compare the unedited value with an empty string.
        old = ''
        new = errata_read.call(e, field)
      else
        # This part makes more sense.
        # Compare the unedited value with the new edited value.
        old = errata_read.call(e, field)
        new = params_read.call(field)
      end
      next unless new
      text_diff = diff_as_string(old,new)
      unless text_diff.empty?
        edit_diffs[field] = text_diff
      end
    end
    edit_diffs
  end

  #
  # Hack related to Bz 737706. See the commentary where this gets called.
  #
  def diff_edits_from_empty
    diff_edits(true)
  end

  def notify_docs_changes(diffs)
    return if diffs.keys.empty?

    # Make sure revision update gets saved.. (Bug 857417)
    errata.update_attribute(:revision, errata.revision + 1)

    text_changes = diffs_to_text
    Notifier.docs_text_changed(errata, text_changes, who).deliver

    # A hack so that there is an initial diff showing the original values.
    # (It might be nice to do this when an Errata is created, but it's easier
    # to do it here for now).
    if errata.text_diffs.empty?
      # This is the diff that happened when the errata was created.
      errata.text_diffs << TextDiff.new(
                                        :diff => diffs_to_text(diff_edits_from_empty),
                                        # The reporter must have entered the original text
                                        :user => errata.reporter,
                                        # Let's fudge the timestamp too so it's more correct
                                        :created_at => errata.created_at
                                        )
    end

    # This is the diff that happened just now
    errata.text_diffs << TextDiff.new(:diff => text_changes, :user => who)

    # If the errata was previously approved we want to invalidate
    # that approval since something has been changed. Note, this will
    # also move a PUSH_READY errata back to REL_PREP.
    # This may invalidate not only the docs approval, but also other
    # approvals which depend on docs.
    errata.invalidate_approvals!(:reason => 'a docs update')
  end
end
