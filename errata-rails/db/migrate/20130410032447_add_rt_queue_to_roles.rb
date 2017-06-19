class AddRtQueueToRoles < ActiveRecord::Migration
  def self.up
    add_column :roles, :rt_queue,    :string, :default => nil
    add_column :roles, :rt_email,    :string, :default => nil
    add_column :roles, :irc_channel, :string, :default => nil
    add_column :roles, :team_name,   :string, :default => nil

    #
    # See Bug 674454.
    # Might add info for other roles later.
    #
    Role.find_by_name('releng').update_attributes(
      :rt_queue    => 'release-engineering',
      :rt_email    => 'release-engineering',
      :irc_channel => 'rel-eng',
      :team_name   => 'Release Engineering Team'
    )

    Role.find_by_name('secalert').update_attributes(
      :rt_queue    => 'security-response',
      :rt_email    => 'secalert',
      :irc_channel => '0day',
      :team_name   => 'Security Response Team'
    )
  end

  def self.down
    remove_column :roles, :rt_queue
    remove_column :roles, :rt_email
    remove_column :roles, :irc_channel
    remove_column :roles, :team_name
  end

end
