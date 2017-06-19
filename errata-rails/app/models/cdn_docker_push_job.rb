class CdnDockerPushJob < PushJob
  include LivePushTasks

  def push_details
    {
      'can' => errata.has_docker?,
      'blockers' => errata.push_cdn_docker_blockers,
      'target' => self.target
    }
  end

  def valid_pre_push_tasks
    PRE_PUSH_TASKS.slice('set_in_push')
  end

  def valid_post_push_tasks
    POST_PUSH_TASKS.slice('mark_errata_shipped', 'check_error')
  end

end
