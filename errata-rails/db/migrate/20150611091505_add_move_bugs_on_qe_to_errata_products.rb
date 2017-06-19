class AddMoveBugsOnQeToErrataProducts < ActiveRecord::Migration

  def up
    add_column :errata_products, :move_bugs_on_qe, :boolean,
      :default => false, :null => false

    # Update RHEV product to set the move_bugs_on_qe flag
    Product.find_by_short_name('RHEV').update_attribute(:move_bugs_on_qe, true)

  end

  def down
    remove_column :errata_products, :move_bugs_on_qe
  end
end
