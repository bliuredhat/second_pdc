class AlterAutowaiveRuleForResultDetails < ActiveRecord::Migration
  def up
    add_column :rpmdiff_autowaive_rule, :score, :integer, :null => false, :references => :rpmdiff_scores

    add_column :rpmdiff_autowaive_rule, :content_pattern, :text, :null => false

    change_column :rpmdiff_autowaive_rule, :string_expression, :string, :limit => 1000, :null => true

    ActiveRecord::Base.transaction do
      RpmdiffAutowaiveRule.all.each do |r|
        r.update_attributes!(:content_pattern => r.string_expression, :active => false)
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      RpmdiffAutowaiveRule.all.each do |r|
        r.update_attributes!(:string_expression => r.content_pattern)
      end
    end
    remove_column :rpmdiff_autowaive_rule, :content_pattern

    change_column :rpmdiff_autowaive_rule, :string_expression, :string, :limit => 1000, :null => false

    remove_column :rpmdiff_autowaive_rule, :score
  end
end
