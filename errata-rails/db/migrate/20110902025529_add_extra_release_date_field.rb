#
# The release_date field has always been used only for RHSA advisories and
# really means 'embargo date'.
#
# Want to be able to record a release date that is different from the
# embargo date, so hence a new column is needed.
#
# Going to keep the release_date field as is (but will call it Embargo
# date in the UI).
#
# (Bug 736902)
#
class AddExtraReleaseDateField < ActiveRecord::Migration
  def self.up
    # Call it override since mostly it will be nil which means 'use default'.
    # Putting an actual date in there gives a 'custom' release date.
    add_column :errata_main, :publish_date_override, :datetime
  end

  def self.down
    remove_column :errata_main, :publish_date_override
  end
end
