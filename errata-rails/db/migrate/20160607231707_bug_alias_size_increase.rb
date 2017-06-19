class BugAliasSizeIncrease < ActiveRecord::Migration
  def up
    # Making this column unlimited isn't feasible due to
    # problems with setting index length in Rails 3.2.
    # So we'll use a size big enough for 200 5-digit CVEs,
    # and go with the default index size of 255.
    change_column :bugs, :alias, :string, :limit => 3200
  end
  def down
    # Warning: this loses data by truncating the field length!
    change_column :bugs, :alias, :string
  end
end
