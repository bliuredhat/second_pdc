#
# See Bug 983932.
# Need more space to hold product listing cache yaml for texlive.
#
class ProdListingCacheSizeIncrease < ActiveRecord::Migration
  def self.up
    # Using 0x555555 instead of (expected) 0xffffff below to ensure we geta mysql
    # mediumtext and not a longtext. It's related to utf-8 vs latin-us encoding and
    # a bug in our version of rails. See https://github.com/rails/rails/issues/3931
    change_column :product_listing_caches, :cache, :text, :limit => 0x555555
  end

  def self.down
    # Default limit is 0xffff in a mysql 'text' field
    change_column :product_listing_caches, :cache, :text
  end
end
