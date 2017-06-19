class AddCdnDockerPushTarget < ActiveRecord::Migration
  # This class must be loaded for validation to pass
  [CdnDockerPushJob]

  def up
    ActiveRecord::Base.transaction do
      Settings.pub_push_targets = Settings.pub_push_targets.merge(Settings.defaults[:pub_push_targets].slice('cdn_docker'))
      PushTarget.create!(
        :name => 'cdn_docker',
        :description => 'Push docker images to CDN',
        :push_type => 'cdn_docker',
        :is_internal => false
      )
    end
  end

  def down
    ActiveRecord::Base.transaction do
      PushTarget.where(:push_type => 'cdn_docker').destroy_all
      Settings.pub_push_targets = Settings.pub_push_targets.except('cdn_docker')
    end
  end
end
