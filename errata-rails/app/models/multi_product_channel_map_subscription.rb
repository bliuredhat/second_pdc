class MultiProductChannelMapSubscription < ActiveRecord::Base
  include MultiProductMapSubscription

  belongs_to :multi_product_channel_map

end
