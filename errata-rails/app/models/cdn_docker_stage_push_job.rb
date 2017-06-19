class CdnDockerStagePushJob < PushJob
  def push_details
    {
      'can' => errata.has_docker?,
      'blockers' => errata.push_cdn_docker_stage_blockers,
      'target' => self.target
    }
  end

end
