class PrepareProductSpecificRpmDiffAutowaiveRule < ActiveRecord::Migration
  def up
    create_table :rpmdiff_autowaive_product_versions do |t|
      t.integer :product_version_id, :null => false
      t.integer :autowaive_rule_id, :null => false
    end
    add_index(:rpmdiff_autowaive_product_versions,
              [:product_version_id],
              :name => 'product_version_id')
    add_index(:rpmdiff_autowaive_product_versions,
              [:autowaive_rule_id],
              :name => 'autowaive_rule_id')
    add_foreign_key(:rpmdiff_autowaive_product_versions,
                    :product_version_id,
                    :product_versions, :id,
                    :name => 'rpmdiff_autowaive_product_versions_ibfk_1')
    add_foreign_key(:rpmdiff_autowaive_product_versions,
                    :autowaive_rule_id,
                    :rpmdiff_autowaive_rule, :autowaive_rule_id,
                    :name => 'rpmdiff_autowaive_product_versions_ibfk_2')
  end

  def down
    drop_table :rpmdiff_autowaive_product_versions
  end
end
