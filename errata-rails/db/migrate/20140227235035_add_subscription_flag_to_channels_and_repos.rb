class AddSubscriptionFlagToChannelsAndRepos < ActiveRecord::Migration
  def change
    add_column :channels, :has_stable_systems_subscribed, :boolean, :null => false, :default => false
    add_column :cdn_repos, :has_stable_systems_subscribed, :boolean, :null => false, :default => false
  end
end
