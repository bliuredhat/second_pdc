class RemoveDeadTpsjobColumns < ActiveRecord::Migration
  def self.up
    remove_column :tpsjobs, :rhn_channel_id
    remove_column :tpsjobs, :product_variant_id
  end

  def self.down
  end
end
