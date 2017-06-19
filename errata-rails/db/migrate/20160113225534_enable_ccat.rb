class EnableCcat < ActiveRecord::Migration
  TEST_TYPE = 'ccat'

  def up
    # This test type is applicable to every rule set.
    rulesets.each do |rs|
      rs.test_requirements << TEST_TYPE
      rs.save!
    end
  end

  def down
    rulesets.each do |rs|
      rs.test_requirements -= [TEST_TYPE]
      rs.save!
    end
  end

  def rulesets
    # This test type is applicable to every rule set.
    StateMachineRuleSet.all
  end
end
