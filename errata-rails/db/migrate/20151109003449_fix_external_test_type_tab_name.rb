class FixExternalTestTypeTabName < ActiveRecord::Migration
  def up
    # Fix up blank tab name(s).
    #
    # This field was supposed to be set in AddTabNameToExternalTestType.
    # Instead, it was set to blank, due to cached column info.
    #
    # Fix it here and set the tab name as expected.
    #
    # This will work correctly since reset_column_information was called after
    # the table was modified and before this migration.
    ExternalTestType.all.select{ |t| t.tab_name.blank? }.each do |t|
      t.tab_name = t.name.titleize
      t.save!
    end
  end

  def down
  end
end
