class AddPdcProductToProduct < ActiveRecord::Migration
  def up
    add_column :errata_products, :pdc_product_id, :integer, :null => true
    add_foreign_key :errata_products, :pdc_product_id, :pdc_resources, :id, :name => 'product_pdc_product_id_fk', :on_delete => :restrict
  end

  def down
    remove_column :errata_products, :pdc_product_id
  end
end
