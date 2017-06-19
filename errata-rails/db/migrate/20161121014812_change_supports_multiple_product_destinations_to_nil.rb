class ChangeSupportsMultipleProductDestinationsToNil < ActiveRecord::Migration
  def up
    change_column :errata_main,
                  :supports_multiple_product_destinations,
                  :boolean,
                  :default => nil,
                  :null => true
  end

  def down
    change_column :errata_main,
                  :supports_multiple_product_destinations,
                  :boolean,
                  :default => true,
                  :null => false
  end
end
