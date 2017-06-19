#
# Mixin concern to share common functionality between RhnTps jobs. This
# should usually go into a base class and RhnTpsJob/RhnQATpsJob inherits
# from it. Yet for a few methods I think the concern is the better place
# instead of a bigger hierarchy. Re-factor if it gets too big.
#
# Bug: 1077987
#
module RhnTps
  extend ActiveSupport::Concern

  alias_attribute :dist_source, :channel

  included do
    validates_presence_of :channel
    # should also validate absence of :cdn_repo here probably
  end

  def is_rhn?
    true
  end

  def is_cdn?
    false
  end

  def config
    'rhn'
  end

  def dist_repo_name
    "channel"
  end

end
