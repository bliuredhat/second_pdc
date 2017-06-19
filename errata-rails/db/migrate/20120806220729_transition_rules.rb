class TransitionRules < ActiveRecord::Migration
  def self.up
    create_table :state_machine_rule_sets do |t|
      t.string :name, :null => false
      t.string :description, :null => false
      t.string :test_requirements, :null => false
      t.boolean :is_locked, :null => false, :default => false
      t.timestamps
    end

   create_table :state_transition_guards do |t|
      t.integer :state_machine_rule_set_id, :null => false
      t.integer :state_transition_id, :null => false
      t.string :type, :null => false
      t.string :guard_type, :null => false, :default => 'block'
      t.timestamps
    end


    r = StateMachineRuleSet.create!(:name => 'Default', :description => 'The standard RHEL Errata process')
    nq = StateTransition.find_by_from_and_to 'NEW_FILES', 'QE'
    RpmdiffGuard.create!(:state_machine_rule_set => r,
                         :state_transition => nq)

    # QE to REL_PREP
    qr = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'
    TpsGuard.create!(:state_machine_rule_set => r,
                                 :state_transition => qr)
    TpsRhnqaGuard.create!(:state_machine_rule_set => r,
                          :state_transition => qr)
    DocsGuard.create!(:state_machine_rule_set => r,
                      :state_transition => qr)
    RhnStageGuard.create!(:state_machine_rule_set => r,
                          :state_transition => qr)
    

    rp = StateTransition.find_by_from_and_to 'REL_PREP', 'PUSH_READY'
    ps = StateTransition.find_by_from_and_to 'PUSH_READY', 'SHIPPED_LIVE'

    [rp,ps].each do |t|
      DocsGuard.create!(:state_machine_rule_set => r,
                                   :state_transition => t)
      RhnStageGuard.create!(:state_machine_rule_set => r,
                                   :state_transition => t)

    end

    add_column :errata_main, :state_machine_rule_set_id, :integer
    add_column :errata_products, :state_machine_rule_set_id, :integer
    add_column :releases, :state_machine_rule_set_id, :integer

    Errata.update_all :state_machine_rule_set_id =>  r
    Product.update_all :state_machine_rule_set_id => r
  end

  def self.down
    remove_column :errata_main, :state_machine_rule_set_id
    remove_column :errata_products, :state_machine_rule_set_id
    remove_column :releases, :state_machine_rule_set_id

    drop_table :state_machine_rule_sets
    drop_table :state_transition_guards
  end
end
