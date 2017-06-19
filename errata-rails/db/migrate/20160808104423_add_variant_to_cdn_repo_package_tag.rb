class AddVariantToCdnRepoPackageTag < ActiveRecord::Migration
  def change
    add_column :cdn_repo_package_tags, :variant_id, :integer, :default => nil, :null => true
  end
end
