class CreateFtpExclusions < ActiveRecord::Migration
  def self.up
    create_table :ftp_exclusions, :description => "List of package srpms to not push to ftp" do |t|
      t.column "package_id", :integer, :null => false,
      :description => "References packages(id)"
      
      t.column "product_id", :integer, :null => false,
      :description => "References errata_products(id)"

      t.column "product_version_id", :integer,
      :description => "References product_versions(id)"
      
    end

    add_foreign_key "ftp_exclusions", ["package_id"], "packages", ["id"]      
    add_foreign_key "ftp_exclusions", ["product_id"], "errata_products", ["id"]      
    add_foreign_key "ftp_exclusions", ["product_version_id"], "product_versions", ["id"]      
    
  end

  def self.down
    drop_table :ftp_exclusions
  end
end
