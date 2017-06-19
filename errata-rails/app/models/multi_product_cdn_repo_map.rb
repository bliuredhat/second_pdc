class MultiProductCdnRepoMap < ActiveRecord::Base
  include MultiProductMap
  belongs_to :origin_cdn_repo, :class_name => 'CdnRepo'
  belongs_to :destination_cdn_repo, :class_name => 'CdnRepo'

  alias_method :destination_dist, :destination_cdn_repo

  has_many :multi_product_cdn_repo_map_subscriptions, :dependent => :destroy

  validates_presence_of :origin_cdn_repo,
                        :destination_cdn_repo

  def self.mappings_for_package(origin_cdn_repos, pkg)
    where(:origin_cdn_repo_id => origin_cdn_repos, :package_id => pkg)
  end

  def self.mapping_type
    :cdn_repo
  end
end
