module BrewJobs
  # For Legacy advisory, imports a build along with its product listings
  # for a particular product version.
  # For PDC advisory, only imports a build for a particular pdc release.
  class ImportBuildJob
    def initialize(pv_id_or_pr_id, build_id_or_nvr, is_pdc=false)
      @pv_id_or_pr_id = pv_id_or_pr_id
      @build_id_or_nvr = build_id_or_nvr
      @is_build_id = BrewBuild.looks_like_build_id? @build_id_or_nvr
      @is_pdc = is_pdc
    end

    def task_name
      out = "Fetching#{' build ID' if @is_build_id} #{@build_id_or_nvr}"
      pv_or_pr_class = @is_pdc ? PdcRelease : ProductVersion

      pv_or_pr = pv_or_pr_class.find_by_id(@pv_id_or_pr_id)
      out += " for #{pv_or_pr.short_name}" if pv_or_pr

      out
    end

    def perform
      build = begin
        BrewBuild.make_from_rpc_without_mandatory_srpm(@build_id_or_nvr, :fail_on_missing => false)
      rescue XMLRPC::FaultException => e
        # user input invalid data? No error, just don't fetch the build
        if e.to_s =~ %r{invalid format:}
          BREWLOG.debug "Bailing out due to #{e.inspect}"
          return
        end

        # rethrow anything else
        raise
      end

      if !build
        BREWLOG.debug "There is no build #{@build_id_or_nvr} for import by #{self.class}"
        return
      end

      BREWLOG.debug "Imported #{@build_id_or_nvr}, now looking at product listings."

      pv_or_pr_class = @is_pdc ? PdcRelease : ProductVersion
      pv_or_pr = pv_or_pr_class.find_by_id(@pv_id_or_pr_id)

      if !pv_or_pr
        BREWLOG.debug "There is no #{pv_or_pr_class} #{@pv_id_or_pr_id} - maybe deleted after this job was enqueued."
        return
      end

      # Since a delayed job queue can suffer from congestion, so better to check the rule again here
      if self.class.should_fetch_product_listing?(@pv_id_or_pr_id, build, @is_pdc)
        ProductListing.for_pdc(@is_pdc).find_or_fetch(pv_or_pr, build, :use_cache => false)
        BREWLOG.debug "Cached product listings for #{pv_or_pr.name}, #{build.nvr}."
      else
        BREWLOG.debug "Product listing cache for #{pv_or_pr.name}, #{build.nvr} is depending by at least one advisory so it will not be refreshed."
      end

    end

    def self.enqueue(pv_id_or_pr_id, build_id_or_nvr, is_pdc=false)
      Delayed::Job.enqueue(self.new(pv_id_or_pr_id, build_id_or_nvr, is_pdc), 3)
    end

    def self.should_fetch_product_listing?(pv_id_or_pr_id, build, is_pdc=false)
      # Todo: could create a ProductListing.find_cache_record method for use here maybe
      cache_class, find_method = if is_pdc
        [PdcProductListingCache, :find_by_pdc_release_id_and_brew_build_id]
      else
        [ProductListingCache, :find_by_product_version_id_and_brew_build_id]
      end

      cached = cache_class.send(find_method, pv_id_or_pr_id, build.id)
      # We won't try to re-fetch the product listing if it is already mapped to an advisory
      (cached.nil? || (!cached.has_errata? && cached.listings_empty?))
    end

    # Enqueues an instance of the job if and only if values are not
    # already in the cache.
    def self.maybe_enqueue(pv_id_or_pr_id, build_id_or_nvr, is_pdc=false)
      build = BrewBuild.find_by_id_or_nvr(build_id_or_nvr)
      need_enqueue = build.nil?
      need_enqueue ||= should_fetch_product_listing?(pv_id_or_pr_id, build, is_pdc)

      self.enqueue(pv_id_or_pr_id, build_id_or_nvr, is_pdc) if need_enqueue
    end
  end
end
