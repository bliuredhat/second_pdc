class AddUserSelectableToStateTransitions < ActiveRecord::Migration
  def self.up
    # Flag to set which transitions can show up in select boxes in UI, versus transitions
    # that are purely internal
    add_column :state_transitions, :is_user_selectable, :boolean, :null => false, :default => true
    StateTransition.where(:to => ['DROPPED_NO_SHIP', 'SHIPPED_LIVE', 'IN_PUSH']).update_all(:is_user_selectable => false)
    StateTransition.where(:from => ['SHIPPED_LIVE', 'IN_PUSH']).update_all(:is_user_selectable => false)
  end

  def self.down
    remove_column :state_transitions, :is_user_selectable
  end
end
