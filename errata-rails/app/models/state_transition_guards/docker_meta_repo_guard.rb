class DockerMetaRepoGuard < StateTransitionGuard
  def transition_ok?(errata)
    !(errata.has_docker? && errata.docker_metadata_repos.empty?)
  end

  def ok_message(errata=nil)
    return 'Advisory metadata CDN repos selected' if errata && errata.has_docker?
    'Advisory metadata CDN repos not required'
  end

  def failure_message(errata=nil)
    'Advisory metadata CDN repos not selected'
  end

end
