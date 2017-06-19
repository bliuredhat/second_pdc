class AddAckedToRpmdiffWaiver < ActiveRecord::Migration
  def change
    add_column :rpmdiff_waivers, :acked, :boolean, :null => false, :default => false, :description => "QE ack for this waiver"
    add_column :rpmdiff_waivers, :acked_by, :integer, :null => true, :foreign_key => {:references => :users}
  end
end
