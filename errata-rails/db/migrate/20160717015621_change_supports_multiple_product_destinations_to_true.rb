class ChangeSupportsMultipleProductDestinationsToTrue < ActiveRecord::Migration
  def up
    change_column :errata_main,
                  :supports_multiple_product_destinations,
                  :boolean,
                  :default => true
  end

  def down
    change_column :errata_main,
                  :supports_multiple_product_destinations,
                  :boolean,
                  :default => false
  end
end
