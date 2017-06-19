module PushTargetsWere
  extend ActiveSupport::Concern
  attr_accessor :push_targets_were

  # Clear the old attributes data that used to store the old
  # relation value
  included do
    after_save :clear_push_targets_were
  end

  def clear_push_targets_were
    self.push_targets_were = nil
  end

  def push_targets=(values)
    return super(values) if self.new_record?
    # An ugly way to track relation changes
    old_values = self.push_targets_were || self.push_targets.map(&:id)
    result = super(values)
    new_values = self.push_targets
    if new_values.map(&:id).sort != old_values.sort
      self.push_targets_were ||= old_values
    else
      clear_push_targets_were
    end
    return result
  end
end