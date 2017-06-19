class CveTable < ActiveRecord::Migration
  def self.up
    
    create_table "cves",
    :description => 'Common Vulnerabilities and Exposures (CVE)
' do |t|
      t.column "name", :string, :null => false, :unique => true,
      :description => "CVE Name"

      t.column "bug_id", :integer,
      :description => 'Foreign key to bugs(id). Exists if a complimentary Security bug has been filed for the CVE'

      t.column "created_at", :datetime, :null => false,
      :description => 'Creation timestamp'
      
      t.column "updated_at", :datetime, :null => false,
      :description => 'Update timestamp'
    end

    add_foreign_key "cves", ["bug_id"], "bugs", ["id"]
    
    create_table "errata_cve_maps", 
    :description => "Map of cve to errata" do |t|
      t.column "errata_id", :integer, :null => false,
      :description => "Foreign key to errata_main(id)"

      t.column "cve_id", :integer, :null => false,
      :description => "Foreign key to cves(id)"
      
      t.column "created_at", :datetime, :null => false,
      :description => 'Creation timestamp'

    end
    
    add_foreign_key "errata_cve_maps", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "errata_cve_maps", ["cve_id"], "cves", ["id"]
  end

  def self.down
    drop_table :errata_cve_maps
    drop_table :cves
  end
end

