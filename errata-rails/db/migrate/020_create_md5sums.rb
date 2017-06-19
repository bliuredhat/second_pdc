class CreateMd5sums < ActiveRecord::Migration
  def self.up
    create_table :md5sums, :description => 'md5sums for brew rpms, by sig key' do |t|
      t.column "brew_rpm_id", :integer, :null => false,
      :description => "Foreign key to brew_rpms(id)."
      t.column "sig_key_id", :integer, :null => false,
      :description => "Foreign key to sig_keys(id)."
      t.column "created_at", :datetime, :null => false, 
      :description => "Creation timestamp."
      t.column "value", :string, :null => false, 
      :description => "md5sum result."
    end      
    add_foreign_key "md5sums", ["sig_key_id"], "sig_keys", ["id"]
    add_foreign_key "md5sums", ["brew_rpm_id"], "brew_rpms", ["id"]
    add_index "md5sums", ["sig_key_id", "brew_rpm_id"], :name => "md5sum_sig_rpm_idx"
    
  end

  def self.down
    drop_table :md5sums
  end
end
