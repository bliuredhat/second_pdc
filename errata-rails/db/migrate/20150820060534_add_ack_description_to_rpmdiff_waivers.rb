class AddAckDescriptionToRpmdiffWaivers < ActiveRecord::Migration
  def change
    # When acking an rpmdiff waiver, a note regarding the approval may be
    # recorded here.
    add_column :rpmdiff_waivers, :ack_description, :string, :default => nil
  end
end
