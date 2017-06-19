class AddPushTargetsToProductVersions < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :push_types, :string, :default => nil
    # TODO: Eliminate/rename supports_cdn and forbid_ftp flags,
    # change to methods
    ProductVersion.all.each do |v|
      targets = [:rhn_stage, :rhn_live]
      targets << :cdn if v.supports_cdn?
      targets << :ftp if v.product.allow_ftp? && !v.forbid_ftp?
      v.update_attribute(:push_types, targets)
    end
  end

  def self.down
    remove_column :product_versions, :push_types
  end
end
