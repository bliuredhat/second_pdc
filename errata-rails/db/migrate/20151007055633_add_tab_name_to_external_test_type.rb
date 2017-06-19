class AddTabNameToExternalTestType < ActiveRecord::Migration
  def up
    change_table(:external_test_types) do |t|
      t.column :tab_name, :string
    end

    # NOTE: this doesn't work as expected, but since it has already been applied
    # on some systems, it's retained for posterity.
    # See reset_column_information below.
    ExternalTestType.all.each do |t|
      t.tab_name = t.name.titleize
      t.save!
    end

    change_table(:external_test_types) do |t|
      t.change :tab_name, :string, :null => false
    end

    # This is needed because a later migration within the same release
    # will attempt to create a new record using the new column, which
    # will fail if ActiveRecord still holds the old column info.
    #
    # Note that this should really have been done prior to the setting of
    # tab_name above. Actually, the setting of the tab name there is silently
    # ignored, leading to incorrect blank tab names.
    #
    # Although we could move this up and fix this migration, the migration has
    # already been applied in various environments, so instead we fix it in a
    # later migration so that no special action is required to get the fix.
    ExternalTestType.reset_column_information
  end

  def down
    remove_column :external_test_types, :tab_name
  end
end
