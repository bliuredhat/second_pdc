class ExcludeFtpDebuginfo < ActiveRecord::Migration
  def up
    change_column :rhel_releases, :exclude_ftp_debuginfo, :boolean, :default => true
  end

  def down
    change_column :rhel_releases, :exclude_ftp_debuginfo, :boolean, :default => false
  end
end
