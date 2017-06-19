module FiledLink
  extend ActiveSupport::Concern

  included do
    belongs_to :errata
    belongs_to :user
    belongs_to :state_index
    alias :who :user
    alias :who= :user=

    scope :added_at_index, lambda {|idx| where(:state_index_id => idx)}

    before_validation(:on => :create) do
      self.who ||= User.current_user
      self.state_index = self.errata.current_state_index
    end
  end

  def advisory_state_ok
    return if errata.new_record? || errata.status == State::NEW_FILES
    return if target.is_security_restricted?
    errors.add(:errata, "Cannot add or remove non-security bugs unless in NEW_FILES state")
  end

  def security_valid
    return if errata.is_security?
    errors.add("#{target.display_id}", "Security bug in non-RHSA") if target.is_security?
  end
end
