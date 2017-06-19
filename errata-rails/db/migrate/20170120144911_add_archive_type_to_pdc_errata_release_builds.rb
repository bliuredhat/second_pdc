class AddArchiveTypeToPdcErrataReleaseBuilds < ActiveRecord::Migration
  def up
    add_column :pdc_errata_release_builds, :brew_archive_type_id, :integer, :null => true
    add_foreign_key :pdc_errata_release_builds, :brew_archive_type_id, :brew_archive_types, :id, :name => 'pdc_errata_release_builds_archive_type_ibfk'
  end

  def down
    remove_foreign_key :pdc_errata_release_builds, :pdc_errata_release_builds_archive_type_ibfk
    remove_index(:pdc_errata_release_builds, :name => :pdc_errata_release_builds_archive_type_ibfk)
    remove_column :pdc_errata_release_builds, :brew_archive_type_id
  end
end
