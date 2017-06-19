# Implements a Form Object (aka Presenter) pattern for coordinating object creation
# e.x. http://pivotallabs.com/form-backing-objects-for-fun-and-profit/
#
# Objects mixing in FormObject are expected to implement a persist! method.
# This method should use save! and create! for object creation
#
module FormObject
  extend ActiveSupport::Concern
  extend ActiveModel::Callbacks
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include ActiveRecord::Transactions
  include ActiveRecord::Callbacks

  included do
    define_model_callbacks :create
  end

  def save
    return false unless valid?
    run_callbacks :create do
      persist!
    end
    return errors.empty?
  end

  def save!
    raise(ActiveRecord::RecordInvalid.new(self)) unless valid?
    run_callbacks :create do
      persist!
    end
    raise(ActiveRecord::RecordInvalid.new(self)) unless errors.empty?
  end
end
