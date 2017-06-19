module Audited
  extend ActiveSupport::Concern
  included do
    before_validation(:on => :create) do
      self.who ||= User.current_user
    end
  end
end
