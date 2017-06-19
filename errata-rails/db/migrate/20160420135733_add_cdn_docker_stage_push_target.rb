class AddCdnDockerStagePushTarget < ActiveRecord::Migration
  # This class must be loaded for validation to pass
  [CdnDockerStagePushJob]

  def up
    ActiveRecord::Base.transaction do
      Settings.pub_push_targets = Settings.pub_push_targets.merge(Settings.defaults[:pub_push_targets].slice('cdn_docker_stage'))
      PushTarget.create!(
        :name => 'cdn_docker_stage',
        :description => 'Push docker images to CDN docker stage',
        :push_type => 'cdn_docker_stage',
        :is_internal => false
      )
    end
  end

  def down
    ActiveRecord::Base.transaction do
      PushTarget.where(:push_type => 'cdn_docker_stage').destroy_all
      Settings.pub_push_targets = Settings.pub_push_targets.except('cdn_docker_stage')
    end
  end
end
