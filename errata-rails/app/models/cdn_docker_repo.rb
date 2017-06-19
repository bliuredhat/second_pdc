class CdnDockerRepo < CdnRepo

  # Lookup docker repos by repository name, as returned by lightblue
  def self.for_docker_repo_name(docker_repo_name)
    find_by_name(convert_docker_repo_name(docker_repo_name))
  end

  def self.convert_docker_repo_name(docker_name)
    "redhat-#{docker_name.tr('/','-')}"
  end

  def type_matches_rpm?(brew_rpm)
    false
  end

  def supports_package_mappings?
    true
  end

end
