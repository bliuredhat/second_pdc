class MultiProductCdnRepoMapSubscription < ActiveRecord::Base
  include MultiProductMapSubscription

  belongs_to :multi_product_cdn_repo_map

end
