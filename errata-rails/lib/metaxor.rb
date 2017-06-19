class Metaxor

  attr_reader :warnings
  attr_accessor :warn_on_error

  def initialize(params = {})
    @warn_on_error = params[:warn_on_error]
  end

  def container_content_for_builds(builds, cache_mode=:lazy_fetch)

    #
    # :cache_only     Don't call lightblue, return only cached content
    # :lazy_fetch     Call lightblue only for builds not in cache
    # :update_changed Get all content from lightblue, update cache where
    #                 lastUpdateDate has changed
    # :force_update   Trash the cache, update everything from lightblue
    #
    case cache_mode
    when :lazy_fetch
      (builds_to_fetch, builds_in_cache) = builds.partition{|b| b.container_content.nil?}
    when :cache_only
      (builds_to_fetch, builds_in_cache) = [[], builds]
    when :update_changed, :force_update
      (builds_to_fetch, builds_in_cache) = [builds, []]
    else
      raise 'Unknown cache_mode specified'
    end

    @warnings = []
    begin
      cc = fetch_container_content_for_builds(builds_to_fetch, cache_mode)
    rescue Exception => e
      # rethrow if warnings is not set
      raise unless warn_on_error
      Rails.logger.warn "Exception when fetching builds from Lightblue: #{e.message}"

      # otherwise return cached values and warn
      builds_in_cache = builds
      cc = {}
      @warnings << 'Unable to contact Lightblue, returning cached data'
    end
    builds_in_cache.each { |build| cc[build] = build.container_content }

    # Warns if builds not found, and inits them to nil in cc if required
    if (builds_not_found = builds_to_fetch.select{|build| (cc[build] ||= nil).nil?}).any?
      @warnings << "No container content found for #{'build'.pluralize(builds_not_found.count)}: #{builds_not_found.map(&:nvr).join(', ')}"
    end

    cc
  end

  def latest_repositories_for_nvrs(nvrs)
    c = Lightblue::ErrataClient.new
    latest_response_per_build c.container_image.repositories_for_brew_builds(nvrs)
  end

  private

  def latest_response_per_build(response)

    # Lightblue may return multiple results per build.
    #
    # If any of the results has the 'published' flag set, those should
    # be used in preference to the non-published results. Otherwise,
    # the result with the most recent lastUpdateDate is returned.

    # If any have the published flag, filter out the unpublished ones
    published = ->(x){x.has_key?(:repositories) && x[:repositories].any?{|y| y[:published]}}
    if (response.any? &published)
      response = response.select &published
    end

    # Return most recent result for each build
    sorted_response = response.sort_by{|r| r[:lastUpdateDate] || ''}
    Hash[sorted_response.map{|r| r[:brew][:build]}.zip(sorted_response)].values
  end


  def fetch_container_content_for_builds(builds, cache_mode)
    cc = {}
    return cc if builds.none?

    # builds keyed by nvr, for fast lookup
    builds_by_nvr = Hash[builds.map(&:nvr).zip(builds)]

    # get content for builds from metaxor/lightblue
    content_for_builds = latest_repositories_for_nvrs(builds_by_nvr.keys)

    content_for_builds.each do |content|
      last_update_date = content[:lastUpdateDate]
      nvr = content[:brew][:build]
      build = builds_by_nvr[nvr]
      if (cached_content = build.container_content)
        if cached_content.mxor_updated_at == last_update_date && cached_content.container_repos.present? && cache_mode != :force_update
          # use cached content for this build
          cc[build] = cached_content
          next
        end
        # cached content is invalid (or :force_update)
        cached_content.destroy
      end

      container_repos = (content[:repositories] || []).map do |repo|
        advisory_ids = (repo[:content_advisories] || []).map{|a|a[:id]}
        comparison = repo[:comparison] || {}

        # This ignores any advisories that can't be found,
        # should raise an exception or log a warning?
        errata = Errata.with_fulladvisories(*advisory_ids).order(:id)

        tags = repo[:tags].map{|t| t[:name]}
        ContainerRepo.new(:name => repo[:repository], :tags => tags.join(' '), :errata => errata, :comparison => comparison.to_json)
      end.compact

      cc[build] = ContainerContent.create!(
        :brew_build_id   => build.id,
        :mxor_updated_at => last_update_date,
        :container_repos => container_repos
      )
    end
    cc
  end

end
