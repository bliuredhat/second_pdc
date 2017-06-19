class AddInPushPushReadyTransition < ActiveRecord::Migration
  def self.up
    StateTransition.create!(:from => 'IN_PUSH', :to => 'PUSH_READY', :is_user_selectable => false)
  end

  def self.down
    StateTransition.find_by_from_and_to('IN_PUSH', 'PUSH_READY').delete
  end
end
