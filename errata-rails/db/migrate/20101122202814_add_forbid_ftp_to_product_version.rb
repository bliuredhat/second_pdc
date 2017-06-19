class AddForbidFtpToProductVersion < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :forbid_ftp, :boolean, :default => false
    ProductVersion.update_all "forbid_ftp = 1", "rhel_release_id in (select id from rhel_releases where name like '%Z%')"
    
  end

  def self.down
    remove_column :product_versions, :forbid_ftp
  end
end
