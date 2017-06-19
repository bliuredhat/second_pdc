class CreateSha256sums < ActiveRecord::Migration
  def self.up
    create_table :sha256sums, :description => 'sha256sums for brew rpms, by sig key' do |t|
      t.column "brew_rpm_id", :integer, :null => false,
      :description => "Foreign key to brew_rpms(id)."
      t.column "sig_key_id", :integer, :null => false,
      :description => "Foreign key to sig_keys(id)."
      t.column "created_at", :datetime, :null => false,
      :description => "Creation timestamp."
      t.column "value", :string, :null => false,
      :description => "sha256sum result."
    end
    add_foreign_key "sha256sums", ["sig_key_id"], "sig_keys", ["id"]
    add_foreign_key "sha256sums", ["brew_rpm_id"], "brew_rpms", ["id"]
    add_index "sha256sums", ["sig_key_id", "brew_rpm_id"], :name => "sha256sum_sig_rpm_idx"
  end

  def self.down
    drop_table :sha256sums
  end
end
