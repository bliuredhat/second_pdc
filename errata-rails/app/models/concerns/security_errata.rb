module SecurityErrata
  require 'set'
  extend ActiveSupport::Concern

  included do
    validate :impact_valid

    scope :embargoed, :conditions => ['release_date is not null and release_date > ?', Time.now]
  end

  IMPACTS = ['Low', 'Moderate', 'Important', 'Critical'].freeze

  def is_critical?
    self.security_impact == 'Critical'
  end

  def impact_valid
    return unless self.is_security?
    logger.debug "Validating an RHSA. It has impact: #{security_impact}"
    unless IMPACTS.detect { |i| i == security_impact }
      errors.add(:security_impact, "Invalid security impact #{security_impact} for RHSA")
    end
  end

  def short_impact
    impact = security_impact
    return '' unless impact && impact.length >= 3
    return impact[0..2]
  end

  def synopsis_sans_impact
    return '' unless synopsis
    parts = synopsis.split(': ')
    if parts.length > 1
      return parts[1]
    else
      return synopsis
    end
  end

end
