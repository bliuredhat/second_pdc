class AddExternalTestsGuardTestTypes < ActiveRecord::Migration
  def change
    create_table(:external_tests_guard_test_types) do |t|
      t.references :external_tests_guard, :null => false
      t.references :external_test_type,   :null => false
      t.timestamps
      t.foreign_key ['external_tests_guard_id'], 'state_transition_guards', ['id'], :name => 'guard_ibfk'
      t.foreign_key ['external_test_type_id'],   'external_test_types',     ['id'], :name => 'type_ibfk'
    end
  end
end
