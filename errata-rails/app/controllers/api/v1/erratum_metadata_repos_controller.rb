# :api-category: Pushing Advisories
class Api::V1::ErratumMetadataReposController < Api::V1::ErratumTextOnlyController
  skip_before_filter :ensure_text_only

  before_filter :ensure_docker

  #
  # Get all available CDN repos for advisory metadata.
  # This applies only for advisories containing Docker images.
  #
  # :api-url: /api/v1/erratum/{id}/metadata_cdn_repos
  # :api-method: GET
  #
  # The usage and response format is the same as [GET
  # /api/v1/erratum/{id}/text_only_repos].
  #
  def repos_index
  end

  #
  # Enable or disable metadata CDN repos for an advisory.
  # This applies only for advisories containing Docker images.
  #
  # :api-url: /api/v1/erratum/{id}/metadata_cdn_repos
  # :api-method: PUT
  #
  # The usage and response format is the same as for [PUT
  # /api/v1/erratum/{id}/text_only_repos].
  #
  def repos_update
    if @errata.docker_metadata_repo_list.nil?
      @errata.docker_metadata_repo_list = DockerMetadataRepoList.create(:errata => @errata)
      @errata.save!
    end
    do_update :dist_type => :repo, :dist_class => CdnRepo, :setter => :set_cdn_repos_by_id
  end

  private

  def ensure_docker
    unless @errata.has_docker?
      redirect_to_error!("#{@errata.advisory_name} does not contain Docker images", :unprocessable_entity)
    end
  end

  def find_available_repos
    @available_dists = @errata.active_cdn_repos_for_available_product_versions.select(&:is_binary_repo?)
  end

  def find_active_repos
    @active_dists = @errata.docker_metadata_repo_list.try(:get_cdn_repos) || []
  end
end
