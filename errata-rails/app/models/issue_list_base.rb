class IssueListBase
  include FormObject
  
  def initialize(params)
    ids = params[:ids] || ''
    format = params[:format]
    issue_obj = params[:issue_obj] || raise(ArgumentError, "missing issue_obj")

    # Set some instance variables dynamically
    [:errata, :id_field, :id_prefix, :type].each do |key|
      value = params[key] || raise(ArgumentError, "missing #{key}")
      self.instance_variable_set('@' + key.to_s, value)
    end

    @idsfixed = ids.to_s.split(/,|\s/).reject(&:empty?).uniq
    usable_idsfixed = @idsfixed.map{|id| extract_id(id)}.compact
    if format
      usable_idsfixed = usable_idsfixed.select(&issue_obj.method(format))
    end

    # Set existing advisory bugs/JIRA issues into an array
    found = find_issues usable_idsfixed
    self.instance_variable_set("@" + @type.to_s, found)

    return get_issues_to_fetch(issues, usable_idsfixed)
  end

  def extract_id(id)
    id
  end

  def ids
    issues.map(&@id_field).join(',')
  end

  def idsfixed
    @idsfixed.join(' ')
  end

  def resolved_idsfixed
    out = []
    issues.each do |issue|
      identifiers_for(issue).each do |val|
        [val, @id_prefix + val].each do |candidate|
          if @idsfixed.include?(candidate)
            out << candidate
          end
        end
      end
    end
    out
  end

  def unresolved_idsfixed
    @idsfixed - resolved_idsfixed
  end

  def remove(id)
    i = issues.map(&@id_field).index(id)
    issues.delete_at(i) if i
  end

  def issues_to_add_and_drop
    return issues, [] if @errata.new_record?

    issues_set = issues.to_set
    errata_set = @errata.method(@type).call().to_set

    new_issues = issues_set - errata_set
    removed_issues = errata_set - issues_set
    return new_issues.to_a, removed_issues.to_a
  end

  protected

  def get_issues_to_fetch(known, ids)
    found = known.map{ |issue| identifiers_for(issue) }.flatten.to_set
    ids.reject {|i| found.include? i}
  end

  def issue_rules(params={})
    [:filed_target, :dropped_target].each do |key|
      raise(ArgumentError, "missing #{key}") if params[key].nil?
    end

    filed_target = params[:filed_target]
    dropped_target = params[:dropped_target]

    new_issues, removed_issues = issues_to_add_and_drop
    fis = filed_target.call(new_issues, @errata)
    unless fis.valid?
      errors.add(:idsfixed, fis.errors.full_messages)
    end

    return if removed_issues.empty?
    dis = dropped_target.call(removed_issues, @errata)
    unless dis.valid?
      errors.add(:idsfixed, dis.errors.full_messages)
    end
  end

  def save_issues(params={})
    [:filed_target, :dropped_target].each do |key|
      raise(ArgumentError, "missing #{key}") if params[key].nil?
    end

    filed_target = params[:filed_target]
    dropped_target = params[:dropped_target]

    new_issues, removed_issues = issues_to_add_and_drop
    Errata.transaction do
      filed_target.call(new_issues, @errata).save!
      dropped_target.call(removed_issues, @errata).save!

      send_messages(new_issues, removed_issues)
    end
  end

  def send_messages(new_issues, removed_issues)
    return if new_issues.empty? && removed_issues.empty?

    msg_header = {
      'subject' => 'errata.bugs.changed',
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => @errata.id
    }

    message_new_issues = new_issues.each_with_object([]) do |issue, message_new_issues|
      message_new_issues << {id: issue.id, type: self.class.message_bus_type}
    end

    message_removed_issues = removed_issues.each_with_object([]) do |issue, message_removed_issues|
      message_removed_issues << {id: issue.id, type: self.class.message_bus_type}
    end

    msg_body = {
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => @errata.id,
      'added' => message_new_issues.to_json,
      'dropped' => message_removed_issues.to_json
    }

    MessageBus.enqueue(
      'errata.bugs.changed', msg_body, msg_header,
      :embargoed => @errata.is_embargoed?
    )

  end

  private

  def issues
    self.instance_variable_get("@" + @type.to_s)
  end
end