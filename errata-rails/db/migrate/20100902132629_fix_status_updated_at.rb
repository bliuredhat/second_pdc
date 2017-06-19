class FixStatusUpdatedAt < ActiveRecord::Migration
  def self.up
    tofix = Errata.find :all, :conditions => 'current_state_index_id is not null', :include => [:current_state_index]
    tofix.each {|e| Errata.update_all(["status_updated_at = ?", e.current_state_index.created_at], "id = #{e.id}")}
  end

  def self.down
  end
end
