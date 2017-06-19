class CreateNotScheduledStateForTps < ActiveRecord::Migration
  def up
    # Override the auto-incremental id using :without_protection
    TpsState.create!({:id => 99, :state => tps_state_name}, :without_protection => true)
  end

  def down
    tps_state = TpsState.find_by_state!(tps_state_name)
    jobs_count = TpsJob.where(:state_id => tps_state).count
    if jobs_count > 0
      say "Won't remove TPS state '#{tps_state_name}' because it is being used by #{jobs_count} TPS jobs."
    else
      tps_state.destroy
    end
  end

  private

  def tps_state_name
    "NOT_SCHEDULED"
  end
end
