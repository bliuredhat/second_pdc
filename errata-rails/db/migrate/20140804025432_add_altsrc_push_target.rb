class AddAltsrcPushTarget < ActiveRecord::Migration
  # This class must be loaded for validation to pass
  [AltsrcPushJob]

  def up
    ActiveRecord::Base.transaction do
      Settings.pub_push_targets = Settings.pub_push_targets.merge(Settings.defaults[:pub_push_targets].slice('altsrc'))
      PushTarget.create!(
        :name => 'altsrc',
        :description => 'Push sources to CentOS git',
        :push_type => 'altsrc',
        :is_internal => false
      )
    end
  end

  def down
    ActiveRecord::Base.transaction do
      PushTarget.where(:push_type => 'altsrc').destroy_all
      Settings.pub_push_targets = Settings.pub_push_targets.except('altsrc')
    end
  end
end
