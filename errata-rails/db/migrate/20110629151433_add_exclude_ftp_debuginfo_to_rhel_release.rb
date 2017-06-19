class AddExcludeFtpDebuginfoToRhelRelease < ActiveRecord::Migration
  def self.up
    add_column :rhel_releases, :exclude_ftp_debuginfo, :boolean, :null => false, :default => false
  end

  def self.down
    add_column :rhel_releases, :exclude_ftp_debuginfo
  end
end
