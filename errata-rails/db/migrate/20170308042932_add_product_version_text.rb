class AddProductVersionText < ActiveRecord::Migration
  def change
    add_column :errata_content,
               :product_version_text,
               :text,
               :limit => 4000,
               :default => nil,
               :null => true
  end
end
