module DroppedLink
  extend ActiveSupport::Concern

  included do
    belongs_to :errata
    belongs_to :state_index
    belongs_to :who,
    :class_name => "User"

    scope :dropped_at_index, lambda {|idx| where(:state_index_id => idx)}

    before_validation(:on => :create) do
      self.who ||= User.current_user
    end

    validate(:on => :create) do
      advisory_state_ok
      user_can_drop
    end
  end

  def advisory_state_ok
    return if errata.status_in?(:NEW_FILES, :DROPPED_NO_SHIP)
    return if target.is_security_restricted?
    label = target.class.readable_name
    errors.add(:errata, "Cannot remove non-security #{label.pluralize} unless in NEW_FILES state")
  end

  def user_can_drop
    return unless target.is_security_restricted?
    return if self.who.in_role?('secalert', 'admin')
    label = target.class.readable_name
    error_sym = target.class.name.underscore.to_sym
    errors.add(error_sym, "Only the Security Team can remove security #{label.pluralize} from an advisory")
  end
end
