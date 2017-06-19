module AbidiffTests
  extend ActiveSupport::Concern
  included do
    has_many :abidiff_runs
  end

  def requires_abidiff?
    !self.text_only? && self.state_machine_rule_set.test_requirements.include?('abidiff')
  end

  def abidiff_finished?
    return true unless requires_abidiff?
    return false if self.abidiff_runs.empty?
    self.abidiff_runs.incomplete.count == 0 && self.abidiff_runs.blocking.count == 0
  end
end
