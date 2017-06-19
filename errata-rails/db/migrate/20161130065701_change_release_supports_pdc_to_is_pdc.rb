class ChangeReleaseSupportsPdcToIsPdc < ActiveRecord::Migration
  def change
    rename_column :releases, :supports_pdc, :is_pdc
  end
end
