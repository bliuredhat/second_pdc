module DocumentationWorkflow
  extend ActiveSupport::Concern
  included do
    delegate :docs_unassigned?, :to => :content
  end

  def bugs_requiring_doc_text;     @_bugs_requiring_doc_text     ||= bugs.select { |bug| bug.doc_text_required? }; end
  def bugs_missing_doc_text;       @_bugs_missing_doc_text       ||= bugs.select { |bug| bug.doc_text_missing?  }; end
  def bugs_with_complete_doc_text; @_bugs_with_complete_doc_text ||= bugs.select { |bug| bug.doc_text_complete? }; end

  def bugs_not_requiring_doc_text; @_bugs_not_requiring_doc_text ||= bugs.reject { |bug| bug.doc_text_required? }; end
  def bugs_not_missing_doc_text;   @_bugs_not_missing_doc_text   ||= bugs.reject { |bug| bug.doc_text_missing?  }; end

  def approve_docs!
    update_attributes(:doc_complete=>1, :text_ready=>0)
    notify_observers :after_approve_docs!
  end

  def disapprove_docs!
    notify_observers :after_disapprove_docs! if invalidate_docs_maybe!
  end

  def docs_approval_requested?
    text_ready == 1
  end

  def docs_approved?
    doc_complete == 1 && text_ready == 0
  end

  def docs_approved_or_requested?
    docs_approved? || docs_approval_requested?
  end

  def docs_were_requested?
    state_indices.any? { |state| state.previous == 'QE' || state.current == 'QE' }
  end

  def docs_status_text
    if docs_approved?
      'Approved'
    elsif docs_approval_requested?
      'Requested, not yet approved'
    else
      'Not currently requested'
    end
  end

  def docs_status_text_short
    if docs_approved?
      'Approved'
    elsif docs_approval_requested?
      'Requested'
    elsif docs_were_requested?
      # These would have had docs approval requested
      # and then rejected
      # (Eg when ECS says it needs more work...)
      'Need redraft'
    else
      'Not requested'
    end
  end

  def invalidate_docs!(opts={})
    update_attributes(:doc_complete=>0, :text_ready=>0)
    comments.create(:text => "Documentation approval rescinded#{" due to #{opts[:reason]}" if opts[:reason]}")
    # Invalidating docs for a PUSH_READY advisory triggers a move back to REL_PREP
    # (Use default_qa_user here because unless they are in qa or releng, the current_user isn't permitted to make this state change)
    change_state!(State::REL_PREP, User.default_qa_user, "Documentation is no longer approved") if status_is?(:PUSH_READY)
    return true
  end

  def invalidate_docs_maybe!(opts={})
    doc_complete? ? invalidate_docs!(opts) : false
  end

  def request_docs_approval!
    return false if docs_approval_requested?
    update_attributes(:doc_complete=>0, :text_ready=>1)
    notify_observers :after_request_docs_approval!
    return true
  end

  def requires_docs?
    self.state_machine_rule_set.test_requirements.include?('docs')
  end
end
