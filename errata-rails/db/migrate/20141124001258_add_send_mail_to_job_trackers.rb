class AddSendMailToJobTrackers < ActiveRecord::Migration
  def change
    add_column :job_trackers, :send_mail, :boolean, :default => true, :null => false
  end
end
