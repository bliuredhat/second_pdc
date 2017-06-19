class DropProductConcerns < ActiveRecord::Migration
  def up
    drop_table :product_concerns
  end

  def down
    create_table :product_concerns do |t|
      t.integer :user_id
      t.integer :product_id
      t.datetime :created_at
      t.datetime :updated_at
    end
    add_index(:product_concerns, [:user_id], :name => 'user_id')
    add_index(:product_concerns, [:product_id], :name => 'product_id')
    add_foreign_key(:product_concerns, :user_id, :users, :id, :name => 'product_concerns_ibfk_1')
    add_foreign_key(:product_concerns, :product_id, :errata_products, :id, :name => 'product_concerns_ibfk_2')
  end
end
