module ModelChild
  extend ActiveSupport::Concern

  def self.get_class(name)
    raise ArgumentError, "Missing type." unless name.present?
    name.kind_of?(Class) ? name : name.constantize
  end

  module ClassMethods
    def child_get(child_name)
      klass = ModelChild.get_class(child_name)
      return klass if my_child?(klass)
      raise NameError, "#{child_name} is not a valid type."
    end

    def my_child?(klass)
      klass < self
    end
  end
end