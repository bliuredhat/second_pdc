class AddPdcReleasedPackageIdToReleasedPackageAudits < ActiveRecord::Migration
  def up
    add_column :released_package_audits, :pdc_released_package_id, :integer, :null => true, :index => true,
              :references => :pdc_released_packages, :foreign_key => true
    remove_foreign_key :released_package_audits, :released_package_audits_ibfk_1
    change_column_null :released_package_audits, :released_package_id, true
    add_foreign_key :released_package_audits, :released_package_id, :released_packages,
                    :id, :name => :released_package_audits_ibfk_1
  end

  def down
    # keep the columns whose released_package_id is not null to make sure
    # next add foreign key success
    ReleasedPackageAudit.delete_all("pdc_released_package_id IS NOT NULL")
    remove_column :released_package_audits, :pdc_released_package_id
    remove_foreign_key :released_package_audits, :released_package_audits_ibfk_1
    change_column_null :released_package_audits, :released_package_id, false
    add_foreign_key :released_package_audits, :released_package_id, :released_packages,
                    :id, :name => :released_package_audits_ibfk_1
  end
end
