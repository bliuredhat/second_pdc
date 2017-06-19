class DockerGuard < StateTransitionGuard
  def transition_ok?(errata)

    # Can't transition to PUSH_READY if advisory has docker
    # images that are not mapped to any CDN repository
    # or are not tagged in any mapped repository
    errata.docker_file_repo_map do |mapping, docker_image, repos|
      return false if repos.empty?
      package = docker_image.package
      repos.each do |repo|
        package_mapping = repo.cdn_repo_packages.where(:package_id => package).first
        return false if package_mapping.cdn_repo_package_tags.none?
      end
    end

    true
  end

  def ok_message(errata=nil)
    return 'Advisory does not have docker files' if errata && errata.docker_files.empty?
    'All docker files are mapped to CDN repositories'
  end

  def failure_message(errata=nil)
    return 'Docker mapping checks incomplete' unless errata
    errata.unmapped_docker_message
  end

end
