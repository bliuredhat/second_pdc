class BrewTagsProductVersion < ActiveRecord::Base
  belongs_to :product_version
  belongs_to :brew_tag
end
