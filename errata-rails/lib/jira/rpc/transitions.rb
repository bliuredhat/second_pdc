# Issue transition logic for JIRA RPC clients.
module Jira::Rpc::Transitions
  # Return true if there is a legal transition to +status+ for this +issue+.
  def can_transition_issue?(issue, status)
    begin
      get_transition_with_fields(issue, status)
      return true
    rescue Jira::IllegalTransitionError
      return false
    end
  end

  # Return true if there is a legal transition to close this +issue+.
  def can_close_issue?(issue)
    can_transition_issue?(issue, Settings.jira_closed_status)
  end

  private

  def transitions_rest_url(issue)
    "#{issue_rest_url(issue)}/transitions"
  end

  def get_transition_with_fields(issue, status)
    obj = Jira::Rpc.with_log do
      response = self.get "#{transitions_rest_url(issue)}?expand=transitions.fields"
      JSON.parse(response.body)
    end

    transition = get_transition_to_status obj['transitions'], status
    fields = get_field_values_for_transition issue, transition
    [transition, fields]
  end

  def get_transition_to_status(transitions, status)
    out = transitions.select{|t| t['to']['name'] == status}
    raise Jira::IllegalTransitionError, "No available transition to move to status #{status}" if out.empty?
    raise Jira::IllegalTransitionError, "Multiple transitions to move to status #{status}: #{out}" if out.size > 1
    out[0]
  end

  def get_required_fields_for_transition(transition)
    return {} unless transition.include? 'fields'
    transition['fields'].select{|k,v| v['required']}.each_with_object({}){|f,out| out.merge!(f[0] => f[1])}
  end

  def get_field_values_for_transition(issue, transition)
    get_required_fields_for_transition(transition).each_with_object({}) do |kv,out|
      (k,v) = kv
      out.merge!(k => provide_field_for_transition(issue, k,v))
    end
  end

  def provide_field_for_transition(issue, name, meta)
    method = "provide_#{name}_for_transition"
    raise Jira::IllegalTransitionError, "Don't know what value to provide for required field #{name}" unless self.respond_to?(method, true)
    self.send(method, issue, meta)
  end

  def provide_resolution_for_transition(issue, meta)
    allowed = meta['allowedValues'].map{|x| x['name']}
    res = Settings.jira_closed_resolution
    raise Jira::IllegalTransitionError, "Resolution #{res} is not allowed." unless allowed.include? res

    {:name => res}
  end

  def provide_assignee_for_transition(issue, meta)
    # some transitions require an assignee to be set.  We'd like to keep the assignee
    # unmodified, but there seems to be no shortcut to do this, so we retrieve the
    # current assignee and pass it back.
    obj = Jira::Rpc.with_log do
      response = self.get "#{issue_rest_url(issue)}?fields=assignee"
      JSON.parse(response.body)
    end

    # assignee object is expected to either be a valid user with a name, or 'null' meaning unassigned.
    # Pass back the name, or pass back name => nil, to retain the current assignee in both cases.
    val = obj
    %w[fields assignee name].each{|key| val = val.try(:[], key)}

    {:name => val}
  end
end
