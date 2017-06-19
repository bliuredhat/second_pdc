class AddSecurityApprovedToErrata < ActiveRecord::Migration
  def change
    # null:  not requested
    # false: requested, not approved
    # true:  approved
    add_column :errata_main, :security_approved, :boolean, :default => nil, :null => true
  end
end
