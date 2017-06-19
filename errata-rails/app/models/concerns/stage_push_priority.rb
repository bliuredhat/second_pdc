# This module should be included on any push jobs used for staging (rather
# than production).
#
# It will cause push jobs of that type to be queued with a lower priority.
module StagePushPriority
  extend ActiveSupport::Concern

  def default_priority_with_staging
    # Stage priority is 10 less than prod.
    # https://bugzilla.redhat.com/show_bug.cgi?id=1304780#c0
    default_priority_without_staging - 10
  end

  included do |_|
    alias_method_chain :default_priority, :staging
  end
end
