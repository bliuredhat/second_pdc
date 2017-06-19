class CreateStateTransitions < ActiveRecord::Migration
  def self.up
    create_table :state_transitions do |t|
      t.string :from, :null => false
      t.string :to, :null => false
      t.string :roles, :null => false
      t.timestamps
    end
    add_index :state_transitions, [:from, :to]

    StateTransition.create!(:from => 'NEW_FILES', :to => 'QE', :roles => ['devel', 'qa'])

    StateTransition.create!(:from => 'QE', :to => 'NEW_FILES', :roles => ['devel', 'qa', 'pm'])
    StateTransition.create!(:from => 'QE', :to => 'REL_PREP', :roles => ['qa'])

    ['NEW_FILES', 'QE', 'PUSH_READY'].each do |to|
      StateTransition.create!(:from => 'REL_PREP', :to => to, :roles => ['qa', 'releng'])
    end
    StateTransition.create!(:from => 'PUSH_READY', :to => 'REL_PREP', :roles => ['qa', 'releng'])
    StateTransition.create!(:from => 'PUSH_READY', :to => 'SHIPPED_LIVE', :roles => ['releng'])
    StateTransition.create!(:from => 'SHIPPED_LIVE', :to => 'REL_PREP', :roles => ['releng'])

    ['NEW_FILES', 'QE', 'REL_PREP', 'PUSH_READY'].each do |from|
      StateTransition.create!(:from => from, :to => 'DROPPED_NO_SHIP', :roles => ['pm'])
    end

    StateTransition.create!(:from => 'DROPPED_NO_SHIP', :to => 'NEW_FILES', :roles => ['pm'])
  end

  def self.down
    drop_table :state_transitions
  end
end
