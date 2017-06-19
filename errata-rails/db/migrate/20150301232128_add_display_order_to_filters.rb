class AddDisplayOrderToFilters < ActiveRecord::Migration
  INITIAL_ORDER = [
    'Active Advisories (Default)',
    'Active, assigned to you',
    'Active, reported by you',
    'All NEW_FILES',
    'All PUSH_READY',
    'All SHIPPED_LIVE',
  ]

  def up
    add_column :errata_filters, :display_order, :integer,
      :default => nil

    value = 1000
    INITIAL_ORDER.each do |name|
      SystemErrataFilter.where(:name => name).update_all(:display_order => value)
      value = value + 1000
    end
  end

  def down
    remove_column :errata_filters, :display_order
  end
end
