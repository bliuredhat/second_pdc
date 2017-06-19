class ReleaseEngineeringController < ApplicationController
  include SharedControllerNav
  include ReplaceHtml

  before_filter :allowed_to_add_released_package, :only => :add_released_package
  before_filter :allowed_to_remove_released_package, :only => :remove_released_package

  before_filter :set_index_nav
  before_filter :time_since, :only => [:builds_added_since]
  before_filter :set_pv_and_builds, :only => [:released_packages, :remove_released_package]

  def index
    redirect_to :action => :released_packages
  end

  def add_released_package
    if request.format.html?
      @product_versions = ProductVersion.find_active
      # Set default form values
      @selected_product_version = @product_versions.first
      # Validate brew build version by default
      @check_brew_build_version = true
      set_page_title "Add or Update Released Packages"
    end
    @released_packages_valid = true

    return unless request.post?

    @check_brew_build_version = !params[:skip_brew_build_version_check].to_bool
    input = params[:input]
    @raw_nvrs = input.fetch(:nvrs, '')
    nvrs = (@raw_nvrs.kind_of?(Array) ? @raw_nvrs : @raw_nvrs.split).uniq
    @selected_product_version = ProductVersion.find_by_id_or_name(input[:product_version])
    @reason = input[:reason]


    # User clicks cancel button
    return if request.format.html? && params.fetch(:commit, '') == 'Cancel'

    @errors = if nvrs.blank?
      ['Please provide one or more brew builds.']
    elsif @selected_product_version.blank?
      ['Please provide a product version.']
    elsif @reason.blank?
      ['Please provide a reason.']
    elsif @check_brew_build_version
      # Normally, user will try to add the existing brew builds to become released packages.
      # If there is a case that user trying to add brew builds that don't exist in ET yet,
      # then the brew build version check will be handled by the delayed job. This is because
      # fetching new brew builds from XMLRPC can be very time consuming and may cause the page
      # to load slower.
      @released_packages_valid = @selected_product_version.can_add_builds_as_released?(nvrs)
      @selected_product_version.errors.full_messages
    else
      []
    end

    if @errors.any?
      if !request.format.html? || @released_packages_valid
        opts = {:status => :unprocessable_entity, :on_error_render_page => :add_released_package}
        respond_with_error(@errors.join(" "), opts)
      end
      return
    end

    # ### create an audit trail ###
    # since creation of the ReleasedPackages records are deferred (send_later);
    # create a record with the user input. This record can be later queried for
    # errors as there would be a ReleasePackageUpdate without any associations
    # in audit table - released_package_audits.
    # update is passed to make_released_packages_for_build which must
    # associate the update with new ReleasedPackage
    update = ReleasedPackageUpdate.create!(:reason => @reason, :user_input => input)
    extras = { :check_brew_build_version => @check_brew_build_version }

    @job_tracker = JobTracker.track_jobs(
        "#{@selected_product_version.name} Released Package Load",
        "Adding/updating #{nvrs.length} released packages") do

      nvrs.each do |nvr|
        ReleasedPackage.send_later(
          :make_released_packages_for_build,
          nvr, @selected_product_version, update, extras
        )
      end
    end

    notice = "Job to load released packages has been submitted to the background queue." +
      " You will be notified by email when it completes"
    respond_with_success(notice, :location => job_tracker_path(@job_tracker), :jbuilder => 'job_trackers/show')
  end

  def builds_added_since
    @errata_builds = ErrataBrewMapping.find(:all,
                                            :conditions =>
                                            ['current = 1 and errata_brew_mappings.created_at >= ?', @since],
                                            :include => [:brew_build, :errata],
                                            :order => 'errata_brew_mappings.created_at')

    @errata_builds += PdcErrataReleaseBuild.find(:all,
                                                :conditions =>
                                                ['current = 1 and pdc_errata_release_builds.created_at >= ?', @since],
                                                :include => [:brew_build, :errata],
                                                :order => 'pdc_errata_release_builds.created_at')
    title = "Builds Added "
    title += "Since " unless @timeframe == 'today'
    set_page_title title + @timeframe.capitalize

  end

  def builds_for_release
    @releases = Release.current.enabled
    set_current_release
    @advisories = @current_release.errata
    @advisories.sort! { |a,b| a.shortadvisory <=> b.shortadvisory }
    respond_to do |format|
      format.html { set_page_title "Brew Builds for Advisory in #{@current_release.name}" }
      format.json do
        list = []
        @advisories.each do |e|
          hsh = { :id => e.id,
            :advisory_name => e.shortadvisory,
            :product => e.product.short_name,
            :synopsis => e.synopsis,
            :status => e.status.to_s,
            :respin_count => e.respin_count,
            :builds => []
          }
          e.build_mappings.each do |map|
            hsh[:builds] << { :build_tag => map.build_tag,
              :brew_build_nvr => map.brew_build.nvr}
          end
          list << hsh
        end
        render :json => list.to_json
      end
    end
  end

  def product_listings
    extra_javascript 'product_listings'

    @product_versions = ProductVersion.find_active
    set_page_title "Product Listings"
    @statements = []
    @listing_info = ''
    return unless params[:rp]

    pv_id = params[:rp][:pv_or_pr_id]
    nvr = params[:rp][:nvr].strip
    return unless pv_id && nvr

    @debug = params[:rp][:debug].to_bool
    @product_version = ProductVersion.find(pv_id)

    begin
      @brew_build = BrewBuild.make_from_rpc_without_mandatory_srpm(nvr)
    rescue => e
      flash_message :error, "Could not find brew build #{nvr}"
      redirect_to :action => 'product_listings'
      return
    end

    # Note that this action must not save/update product listing
    # caches, because that would bypass the usual "reload files" logic
    # which ensures tests are rescheduled as needed.
    opts = {:use_cache => false, :save => false}

    if @debug
      @debug_variant_map = debug_product_listing_variant_map(@product_version, @brew_build.package)
      @debug_fetched = []
      opts[:around_filter] = debug_product_listing_fetch(@debug_fetched)
    end

    begin
      @listing = ProductListing.find_or_fetch(@product_version, @brew_build, opts)
    rescue XMLRPC::FaultException, Errno::ECONNREFUSED,
           Errno::EHOSTDOWN, Errno::EHOSTUNREACH => ex
      error = ex
      # Note: the Errno exceptions are logged in brew.log.
    end

    if error.present?
      @brew_error = error.to_s
    elsif @listing.empty?
      @statements << "No product listing data found!"
    end

    @cached_listing = ProductListingCache.cached_listing(@product_version, @brew_build)

    @cached_listings_match = @cached_listing &&
      ProductListing.listings_match(@listing, @cached_listing.get_listing)

    set_page_title "Product Listings for #{@product_version.name} Build #{@brew_build.nvr}"

  end

  def pdc_product_listings
    extra_javascript 'product_listings'
    @pdc_releases = PdcRelease.active_releases
    if @pdc_releases.empty?
      redirect_to_error!("No active releases or can't access PDC server")
    end
    set_page_title "PDC Product Listings"
    @statements = []
    @listing_info = ''
    return unless params[:rp]

    pr_id = params[:rp][:pv_or_pr_id]
    nvr = params[:rp][:nvr].strip
    return unless pr_id && nvr

    @pdc_release = PdcRelease.find(pr_id)

    begin
      @brew_build = BrewBuild.make_from_rpc_without_mandatory_srpm(nvr)
    rescue => e
      flash_message :error, "Could not find brew build #{nvr}"
      redirect_to :action => 'pdc_product_listings'
      return
    end

    # Note that this action must not save/update pdc product listing
    # caches, because that would bypass the usual "reload files" logic
    # which ensures tests are rescheduled as needed.
    opts = {:use_cache => false, :save => false}

    begin
      @listing = PdcProductListing.find_or_fetch(@pdc_release, @brew_build, opts)
    rescue PDC::Error => ex
      error = ex
      # Note: the Errno exceptions are logged in brew.log.
    end

    if error.present?
      @brew_error = error.to_s
    elsif @listing.empty?
      @statements << "No product listing data found!"
    end

    @cached_listing = PdcProductListingCache.find_cached_listings(@pdc_release, @brew_build)
    @cached_listings_match = @cached_listing && @cached_listing == @listing

    set_page_title "PDC Product Listings for #{@pdc_release.short_name} Build #{@brew_build.nvr}"
  end

  def product_listing_cache
    id = params[:id]
    @cached_listing = ProductListingCache.find_by_id(id)
    return unless @cached_listing

    @advisories = @cached_listing.errata_brew_mappings.map(&:errata).uniq
    set_page_title "Cached Product Listings for #{@cached_listing.product_version.name} Build #{@cached_listing.brew_build.nvr}"
  end

  def clear_product_listing_cache
    id = params[:id]
    @cached_listing = ProductListingCache.find(id)
    flash_message :notice, "Deleted Cached Product Listings for #{@cached_listing.product_version.name} Build #{@cached_listing.brew_build.nvr}"
    @cached_listing.destroy
    redirect_to :action => :product_listings
  end

  # Tests how ET would query product listings, but doesn't actually do
  # the query.
  def product_listings_prefetch_debug
    pv_id = params[:rp][:pv_or_pr_id]
    nvr = params[:rp][:nvr]
    nvr = '(build_nvr)' if nvr.blank?

    @product_version = ProductVersion.find(pv_id)
    @brew_build = BrewBuild.find_by_nvr(nvr)

    package = if @brew_build
      @brew_build.package
    else
      # If we don't have a brew build, still try to figure out the
      # package, so we can produce an accurate @debug_variant_map.
      Package.for_nvr(nvr)
    end

    @debug_would_fetch = debug_product_listing_would_fetch(@product_version, nvr)
    @debug_variant_map = debug_product_listing_variant_map(@product_version, package)

    render :js => js_for_template('product-listings-prefetch-debug', 'product_listings_prefetch_debug')
  end

  def released_packages
    extra_javascript 'change_handler'
    # For the product version drop-down instant submit
    return redirect_to :action => :released_packages, :id => params[:pv][:id] if request.post?

    set_page_title @pv.present? ? "Released Brew Builds for #{@pv.name}" : 'No Product Version Selected'

    @can_remove_released_packages = current_user.can_remove_released_packages?
  end

  def remove_released_package
    extra_javascript %w[change_handler remove_released_package]
    set_page_title @pv.present? ? "Remove Released Brew Builds for #{@pv.name}" : 'No Product Version Selected'

    if request.post?
      builds_ids_to_remove = params[:released_builds_to_remove]
      if !builds_ids_to_remove || builds_ids_to_remove.empty?
        flash_message :warning, "No packages selected for removal!"
      else
        @pv.released_packages.where(:brew_build_id => builds_ids_to_remove).update_all(:current => false)
        flash_message :notice, "#{view_context.n_thing_or_things(builds_ids_to_remove, 'package')} removed."
      end
      redirect_to :action => :released_packages, :id => @pv.id
    end
  end

  def show_released_build
    build = BrewBuild.find(params[:id])
    maps = ErrataBrewMapping.current.where(:brew_build_id => build).joins(:errata).merge(Errata.shipped_live)
    if maps.empty?
      if params[:product_version_id]
        pv = ProductVersion.find(params[:product_version_id])
        maps << ErrataBrewMapping.new(:brew_build => build, :product_version => pv, :package => build.package)
      else
        ids = ProductVersion.connection.select_values("select distinct product_version_id from released_packages where current = 1 and brew_build_id = #{build.id}")
        pvs = ProductVersion.find ids
        pvs = pvs.select {|pv| pv.product.isactive?}
        pvs.each { |pv| maps << ErrataBrewMapping.new(:brew_build => build, :product_version => pv, :package => build.package) }
      end
    end
    @build = build
    @maps_channels = maps.each_with_object({}) { |map,h| h[map] = rpm_channel_map(map)}
    @advisories = maps.reject {|m| m.errata.nil?}.map(&:errata)
    respond_to do |format|
      format.html { set_page_title "Released packages for build #{build.nvr} in #{maps.collect { |m| m.product_version.name}.join(',')}"}
      format.json do
        hsh = {:build => build.nvr}
        @advisories.each do |e|
          hsh[:errata] ||= []
          hsh[:errata] << { :id => e.id, :advisory_name => e.shortadvisory }
        end
        hsh[:product_versions] = { }
        @maps_channels.each_pair do |map, channel_rpms|
          hsh[:product_versions][map.product_version.name] = channel_rpms
        end
        render :json => hsh.to_json
      end
    end
  end

  def errata_to_push
  end

  protected

  def set_pv_and_builds
    @product_versions = ProductVersion.find_active # for drop down select
    @pv = ProductVersion.find_by_id(params[:id])
    @builds = @pv ? BrewBuild.released_builds(@pv) : BrewBuild.where('1 = 0')
  end

  def get_secondary_nav
    nav = []
    if current_user.can_see_add_released_packages_tab?
      nav << { :name => 'Add/Update Released Packages', :controller => :release_engineering, :action => :add_released_package}
    end
    nav << { :name => 'Browse Released Packages', :controller => :release_engineering, :action => :released_packages, :also_selected_for => :remove_released_package }
    nav << { :name => 'Builds By Advisory', :controller => :release_engineering, :action => :builds_for_release}
    nav << { :name => 'Product Listings', :controller => :release_engineering, :action => :product_listings}
    nav << { :name => 'PDC Product Listings', :controller => :release_engineering, :action => :pdc_product_listings}
    nav << { :name => 'Builds Added Since', :controller => :release_engineering, :action => :builds_added_since}
    return nav
  end

  def rpm_channel_map(map)
    rpm_channels = HashList.new
    return rpm_channels unless map.for_rpms?

    classes = [PrimaryChannel]
    if map.errata
      if map.errata.release.is_fasttrack?
        classes << FastTrackChannel
      elsif map.errata.release.is_async? && map.product_version.is_zstream?
        classes << EusChannel
        classes << LongLifeChannel
      end
    end

    no_src = FtpExclusion.is_excluded?(map.package, map.product_version)
    map.build_product_listing_iterator do |rpm,variant, brew_build, arch_list|
      next if rpm.is_debuginfo?
      next if rpm.is_srpm? && no_src
      arch_list.each do |arch|
        channels = map.product_version.active_channels.where('channel_links.variant_id = ? and arch_id = ? and type in (?)',
                                                             variant,
                                                             arch,
                                                             classes.collect {|c| c.to_s})
        next if channels.empty?
        channels.each { |channel| rpm_channels[channel.name] << rpm.rpm_name }
      end
    end
    return rpm_channels
  end

  def set_current_release
    release_id = params[:release_id]
    unless release_id
      @current_release = @releases.first
      return
    end

    if release_id =~ /^[0-9]+$/
      @current_release = Release.find(release_id.to_i)
    else
      @current_release = Release.find_by_url_name(release_id)
    end
  end

  def allowed_to_add_released_package
    validate_user_permission(:add_released_packages)
  end

  def allowed_to_remove_released_package
    validate_user_permission(:remove_released_packages)
  end

  def debug_product_listing_would_fetch(product_version, nvr=nil)
    build = nvr ? BrewBuild.find_by_nvr(nvr) : nil

    if !build
      # We support the case that the user wants to know about a build
      # which ET doesn't have yet.  In that case, pass in a fake build
      # object with placeholders.
      build = BrewBuild.new
      build.nvr = nvr || 'build-1.2.3-4.el7.5'
      def build.id
        '<build_id>'
      end
      if nvr
        def build.package
          Package.for_nvr(nvr)
        end
      end
    end

    would_do = []
    ProductListing.find_or_fetch(product_version, build,
      :use_cache => false,
      :around_filter => lambda{|what| would_do << what; {}})

    would_do
  end

  def debug_product_listing_variant_map(in_product_version, package)
    out = Hash.new{|h,k| h[k] = {}}

    product_versions = [in_product_version]
    if package
      product_versions.concat(
        MultiProductMap.mapped_product_versions(in_product_version, package))
    end

    product_versions.each do |product_version|
      version_number = product_version.rhel_version_number
      variant_map = product_version.version_rhel_map.inject({}) do |h,(label,variant)|
        # Inverse of ErrataBrewMapping#build_product_listing_iterator,
        # which prepends RHEL version number to the labels.
        label = label.gsub(/^#{Regexp.escape(version_number)}/, '')
        h[label] = variant
        h
      end

      product_mapping = product_version.has_split_product_listings? \
        ? product_version.product_mapping \
        : {'' => product_version.name}

      # This block needs to match the logic in
      # ProductListing.get_product_listings_by.
      product_mapping.each do |key,prod|
        variant_map.map do |label,variant|
          if key.blank? || label == key
            # no munging if label matches exactly or we're using unified
            # product listings
            [label, variant]
          elsif label.starts_with?("#{key}-")
            # A product listing label of e.g. "Server-LoadBalancer" will be mapped
            # if we requested listings for e.g. "RHEL-6.6.z-Server" and got a value
            # for "LoadBalancer" in the response.
            [label.gsub(/^#{Regexp.escape key}-/, ''), variant]
          end
        end.compact.each do |label,variant|
          out[prod][label] = variant
        end
      end
    end

    out
  end

  def debug_product_listing_fetch(store)
    lambda do |what,&block|
      begin
        data = nil
        seconds = Benchmark.realtime {
          data = block.call()
        }
        str = ''
        PP.pp(data, str)
        store << [what, str, seconds]
        data
      rescue Exception => e
        store << [what, "(error occurred: #{e.inspect})", nil]
        raise
      end
    end
  end
end
