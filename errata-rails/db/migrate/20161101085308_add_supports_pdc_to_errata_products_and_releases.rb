class AddSupportsPdcToErrataProductsAndReleases < ActiveRecord::Migration
  def up
    add_column :errata_products, :supports_pdc, :boolean, :default => false, :null => false
    add_column :releases, :supports_pdc, :boolean, :default => false, :null => false
    product = Product.find_by_name("PDC Placeholder Product")
    product.update_attributes!(:supports_pdc => true) if product
    release = Async.find_by_name("PDCPlaceholderRelease")
    release.update_attributes!(:supports_pdc => true) if release
  end

  def down
    remove_column :errata_products, :supports_pdc
    remove_column :releases, :supports_pdc
  end
end
