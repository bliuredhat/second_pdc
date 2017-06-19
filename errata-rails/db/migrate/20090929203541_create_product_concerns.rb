class CreateProductConcerns < ActiveRecord::Migration
  def self.up
    create_table :product_concerns do |t|
      t.integer :user_id, :null => :false
      t.integer :product_id, :null => :false
      t.timestamps
    end
    add_foreign_key 'product_concerns', ['user_id'], 'users', ['id']
    add_foreign_key 'product_concerns', ['product_id'], 'errata_products', ['id']
  end

  def self.down
    drop_table :product_concerns
  end
end
