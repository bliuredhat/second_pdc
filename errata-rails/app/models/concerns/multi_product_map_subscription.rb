module MultiProductMapSubscription
  extend ActiveSupport::Concern
  include Audited

  included do
    belongs_to :subscriber,
               :class_name => 'User',
               :foreign_key => 'subscriber_id'

    belongs_to :user,
               :foreign_key => 'who_id'

    alias :who :user
    alias :who= :user=
  end
end
