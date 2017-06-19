module ActiveInactive
  extend ActiveSupport::Concern

  module ClassMethods
    def active
      where(:active => true)
    end

    def inactive
      where(:active => false)
    end
  end

  def make_inactive!
    update_attribute(:active, false)
  end

  def make_active!
    update_attribute(:active, true)
  end
end
