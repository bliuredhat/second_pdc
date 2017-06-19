class DefaultSolution < ActiveRecord::Base
  include CanonicalNames
  include ActiveInactive

  default_scope order('active desc, title')

  # The "default" default solution is no longer the
  # default default solution (lol). See Bug 878069.
  def self.default_default_solution
    self.find_by_title("enterprise")
  end

  def select_title
    "#{title} #{"(retired)" unless active?}"
  end

end
