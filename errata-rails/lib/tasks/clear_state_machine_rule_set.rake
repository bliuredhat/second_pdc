namespace :one_time_scripts do
  #
  # See Bug 978077.
  #
  # New design is that this field is nil unless the
  # advisory has a custom work flow rule set.
  #
  # Otherwise it will use the rule set from the release
  # or the product.
  #
  desc "clear workflow rule set id from errata"
  task :clear_workflow_rule_set_id => :environment do
    using_custom_rule_set = "state_machine_rule_set_id not in (select state_machine_rule_set_id from releases where id = group_id) and state_machine_rule_set_id not in (select state_machine_rule_set_id from errata_products where id = product_id)"
    Errata.where(using_custom_rule_set).update_all(:state_machine_rule_set_id => nil)
  end
end
