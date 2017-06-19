class AddSystemsToTpsJobs < ActiveRecord::Migration
  def self.up
    add_column :tpsjobs, :tps_system_id, :integer
    add_foreign_key "tpsjobs", ["tps_system_id"], "tps_systems", ["id"]

    systems = TpsSystem.find :all, :include => [:arch, :variant]
    systems.each do |s|
      TpsJob.update_all("tps_system_id = #{s.id}", ['arch_id = ? and version_id = ?', s.arch, s.variant])
    end
  end

  def self.down
    drop_column :tpsjobs, :tps_system_id
  end
end
