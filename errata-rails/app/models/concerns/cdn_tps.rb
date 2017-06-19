#
# See rhn_tps.rb concern
#
# Bug: 1077987
#
module CdnTps
  extend ActiveSupport::Concern

  alias_attribute :dist_source, :cdn_repo

  included do
    validates_presence_of :cdn_repo, :on => :create
    # should also validate absence of :channel here probably
  end

  def is_rhn?
    false
  end

  def is_cdn?
    true
  end

  def config
    'cdn'
  end

  def dist_repo_name
    "cdn_repo"
  end

end
