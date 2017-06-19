# :api-category: Legacy
class BrewController < ApplicationController
  include SharedApi::ErrataBuilds
  include ReplaceHtml

  require 'brew'
  skip_before_filter :readonly_restricted, :only => :list_files
  verify :method => :post, :except => [:errata_for_build, :list_files, :request_respin, :builds_added_since, :build_embargoed, :edit_file_meta]

  attr_accessor :product_versions_or_pdc_releases, :product_version_or_pdc_release

  before_filter :find_build, :only => [:errata_for_build, :build_embargoed]

  before_filter :find_mapping, :only => [
    :reload_build,
    :remove_build,
    :reselect_build,
    :request_buildroot_push,
    :cancel_buildroot_push,
  ]

  before_filter :find_errata, :except => [
    :errata_for_build,
    :reload_build,
    :remove_build,
    :reselect_build,
    :request_buildroot_push,
    :cancel_buildroot_push,
    :builds_added_since,
    :build_embargoed,
    :ack_product_listings_mismatch,
  ]

  before_filter :filelist_is_unlocked?, :only => [
    :preview_files,
    :reload_build,
    :remove_build,
    :reselect_build,
    :save_reselect_build,
    :save_builds,
    :put_file_meta_rank,
    :put_file_meta_title,
  ]
  before_filter :allowed_to_request_buildroot_push, :only => :request_buildroot_push
  before_filter :allowed_to_cancel_buildroot_push,  :only => :cancel_buildroot_push

  before_filter :set_index_nav, :only => [:list_files, :edit_file_meta]

  around_filter :with_transaction, :only => [
    :put_file_meta_rank,
    :put_file_meta_title,
    :save_reselect_build
  ]
  around_filter :with_validation_error_rendering, :only => [
    :put_file_meta_rank,
    :put_file_meta_title,
  ]

  def build_embargoed
    maps = ErrataBrewMapping.current.where('brew_build_id = ?', @build).includes(:errata)
    embargoed = maps.any? {|m| m.errata.is_embargoed? }
    respond_to do |format|
      format.json { render :json => embargoed }
      format.any { render :text => embargoed }
    end
  end

  def check_signatures
    updated = 0
    @errata.build_mappings.for_rpms.each do |m|
      updated += 1 if m.update_sig_state
    end
    flash_message :notice, "Updated the signature state of #{updated} builds."
    redirect_to :action => :view, :controller => :errata, :id => @errata
  end

  def errata_for_build
    maps = ErrataBrewMapping.current.where('brew_build_id = ?', @build).includes(:errata)
    @errata = maps.collect { |m| m.errata }

    respond_to do |format|
      format.html do
        set_page_title "Advisories filed for build #{@build.nvr}"
      end
      format.text { render :text =>
        @errata.collect { |e| e.advisory_name }.join("\n") + "\n" }
      format.json { render :layout => false,
        :json => @errata.collect { |e| e.advisory_name }.to_json}
    end
  end

  #
  # Fetch the Brew builds associated with an advisory.
  #
  # The returned builds are organized by product version, variant and
  # RPM.  Non-RPM files are not included in the response.
  #
  # :api-url: /advisory/{id}/builds.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "RHEL-5":
  #   [
  #     {
  #       "postfix-2.3.3-5.el5": {
  #         "5Server": {
  #           "SRPMS": [
  #             "postfix-2.3.3-5.el5.src.rpm"
  #           ],
  #           "i386": [
  #             "postfix-pflogsumm-2.3.3-5.el5.i386.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.i386.rpm",
  #             "postfix-2.3.3-5.el5.i386.rpm"
  #           ],
  #           "x86_64": [
  #             "postfix-pflogsumm-2.3.3-5.el5.x86_64.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.x86_64.rpm",
  #             "postfix-2.3.3-5.el5.x86_64.rpm"
  #           ],
  #           "ppc": [
  #             "postfix-pflogsumm-2.3.3-5.el5.ppc.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.ppc.rpm",
  #             "postfix-2.3.3-5.el5.ppc.rpm"
  #           ],
  #           "s390x": [
  #             "postfix-pflogsumm-2.3.3-5.el5.s390x.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.s390x.rpm",
  #             "postfix-2.3.3-5.el5.s390x.rpm"
  #           ],
  #           "ia64": [
  #             "postfix-pflogsumm-2.3.3-5.el5.ia64.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.ia64.rpm",
  #             "postfix-2.3.3-5.el5.ia64.rpm"
  #           ]
  #        },
  #        "5Client": {
  #           "SRPMS": [
  #             "postfix-2.3.3-5.el5.src.rpm"
  #           ],
  #           "i386": [
  #             "postfix-pflogsumm-2.3.3-5.el5.i386.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.i386.rpm",
  #             "postfix-2.3.3-5.el5.i386.rpm"
  #           ],
  #           "x86_64": [
  #             "postfix-pflogsumm-2.3.3-5.el5.x86_64.rpm",
  #             "postfix-debuginfo-2.3.3-5.el5.x86_64.rpm",
  #             "postfix-2.3.3-5.el5.x86_64.rpm"
  #           ]
  #         }
  #       }
  #     }
  #   ]
  # }
  # ````
  def list_files
    extra_javascript %w[job_trackers view_section]

    respond_to do |format|
      format.json do
        render :layout => false, :json => @errata.build_files_by_nvr_variant_arch.to_json
      end
      format.html do
        set_page_title 'Brew Builds for ' + @errata.fulladvisory + ' - ' + @errata.synopsis
        @user = current_user
        if @errata.filelist_unlocked?
          @valid_tags = {}

          if @errata.is_pdc?
            @current_builds = @errata.build_nvrs_by_pdc_release
            @product_versions_or_pdc_releases, @inactive_product_versions_or_pdc_releases = @errata.available_pdc_releases.partition(&:active?)
            @product_versions_or_pdc_releases.each { |pr| @valid_tags[pr] = pr.valid_tags }
            @product_version_or_pdc_release = 'Pdc Release'
          else
            brew_rpc = Brew.get_connection
            @current_builds = @errata.build_nvrs_by_product_version
            @product_versions_or_pdc_releases, @inactive_product_versions_or_pdc_releases = @errata.available_product_versions.partition(&:enabled?)
            @product_versions_or_pdc_releases.each { |pv| @valid_tags[pv] = brew_rpc.get_valid_tags(@errata, pv)}
            @product_version_or_pdc_release = 'Product Version'
          end
        end

        if @errata.is_pdc?
          # These are used in file_list_pdc partial
          @bb_ids = Set.new
          @version_builds = HashList.new
          @no_listings = HashList.new
          @errata.pdc_errata_release_builds.each do |m|
            @bb_ids << m.brew_build_id
            @version_builds[m.pdc_release] << m
            @no_listings[m.pdc_release] << m.brew_build if !m.rpm_build_has_valid_listing?
          end
        else
          # Similar vars are calculated inside the file_list partial for non-PDC advisories
        end

      end
    end
  end

  def prepare_preview_files

    # Will call this with two different iterators, one for PDC advisories,
    # one for non-PDC advisories
    builds_handler = lambda do |prod_ver_or_pdc_rel, nvrs, related, is_pdc|
      # Always try to import the related nvrs too.  If they exist,
      # we can show them to the user at the next step and prompt for
      # them to be added.  If they don't exist, they may be ignored
      # or an error generated, depending on exactly what the
      # relationship is.
      # Note that currently for PDC advisories, related nvrs will always
      # be empty.
      (nvrs + related.map(&:related_nvr)).each do |nvr|
        BrewJobs::ImportBuildJob.maybe_enqueue(prod_ver_or_pdc_rel.id, nvr, is_pdc)
      end
    end

    @job_tracker = JobTracker.track_jobs(
      "Search builds for #{@errata.advisory_name}",
      "Import a set of builds along with their product listings into Errata Tool's database",
      :max_attempts => 4,
      :send_mail => false
    ) do
      if @errata.is_pdc?
        for_builds_by_pdc_release do |pdc_release, nvrs, related|
          builds_handler.call(pdc_release, nvrs, related, true)
        end
      else
        for_builds_by_product_version do |product_version, nvrs, related|
          builds_handler.call(product_version, nvrs, related, false)
        end
      end
    end

    # In the case that everything was already imported/cached, status
    # 200 tells the caller they can immediately go to the next step.
    # Otherwise we return the job tracker with status 202 Accepted.
    if @job_tracker
      render '/api/v1/job_trackers/show', :status => 202
    else
      render :nothing => true, :status => 200
    end
  end

  def preview_files
    extra_javascript 'brew_file_type_selector'

    # If a job tracker ID for a completed tracker was submitted with
    # this request, we expect that all available data has been loaded
    # already, so we'll strictly use cache.  This is important to
    # avoid spending time again on fetching product listings or builds
    # known to be missing.
    if tracker_id = params['job_tracker_id']
      cache_only = JobTracker.find_by_id(tracker_id).try(:state) == 'FINISHED'
    end

    logger.info "Config parse set to : #{XMLRPC::Config::ENABLE_NIL_PARSER} "
    set_page_title 'Preview New Files for ' + @errata.fulladvisory

    @build_count = 0

    @old_builds_by_product = Hash.new
    @product_builds = Hash.new
    @build_search_errors = HashList.new
    @no_listings = HashList.new

    all_builds = []
    all_related = []
    build_by_nvr = {}

    handle_builds = lambda do |pv_or_pr, build_names, related|
      all_related.concat(related)

      @old_builds_by_product[pv_or_pr] = Brew.get_connection.old_builds_by_package(@errata, pv_or_pr)
      old_builds = @old_builds_by_product[pv_or_pr].values.to_set

      brew_builds = Set.new
      names_with_rel = build_names.map{|nvr| [nvr,nil]} + related.map{|rel| [rel.related_nvr,rel]}
      names_with_rel.each do |name,rel|
        build = (build_by_nvr[name] ||= find_build_by_rpc(name, :cache_only => cache_only))
        next unless build
        next if old_builds.include?(build)

        rpc = Brew.get_connection

        properly_tagged = rpc.build_is_properly_tagged?(@errata, pv_or_pr, build)
        @build_search_errors.list_merge_uniq!(rpc.errors) if rpc.errors.present?
        next unless properly_tagged

        # Bug 1053533
        # Allow rpm builds with empty product listings but give warnings to the user
        # about the missing product listings. Any other errors will not be tolerated.
        # Listing will be emptied when:
        # - It is not yet being set in the composeDB
        # - Brew build not exist
        # - CompseDB is slow and caused XMLRPC to timeout
        if error = build.listing_error(pv_or_pr, :cache_only => cache_only)
          @build_search_errors.list_merge_uniq!({build.nvr => error})
        elsif !build.has_valid_listing?(pv_or_pr)
          @no_listings[pv_or_pr] << build
        end

        @build_count = @build_count + 1
        brew_builds << build
        all_builds << build

        if rel
          rel.satisfied = true
        end
      end

      @product_builds[pv_or_pr] = brew_builds
    end

    if @errata.is_pdc?
      for_builds_by_pdc_release do |pr, build_names, related|
        handle_builds.call(pr, build_names, related)
      end
    else
      for_builds_by_product_version do |pv, build_names, related|
        handle_builds.call(pv, build_names, related)
      end
    end

    @build_relations = all_related
    @content_types = build_content_types(all_builds.to_a)
  end

  def reload_build
    # Note this reloads all mappings on the build!
    # Try to reload files
    begin
      @mapping.errata.build_mappings.where(:brew_build_id => @mapping.brew_build_id).each(&:reload_files)
      msg = "Filelist reloaded for #{@mapping.brew_build.nvr}."
      @errata.comments.create(:who => current_user, :text => msg)
      flash_message :notice, msg
    rescue => e
      # Reload files threw an exception..
      logger.error "Reload Error: #{e.to_s}"
      logger.error e.backtrace.join("\n")
      flash_message :error, "An error occurred reloading files: #{e.to_s}"
    end
    redirect_to :action => 'list_files', :id => @errata
  end

  def remove_build
    # Although we're called with a single mapping, we remove all mappings
    # for this build & product version.
    remove_builds_from_errata(@errata, {
      @mapping.brew_build.id => {:product_versions => {@mapping.product_version.id => {}}}
    })
    redirect_to :action => 'list_files', :id => @errata
  end

  def request_buildroot_push
    change_mapping{|m| m.flags = m.flags + ['buildroot-push']}
  end

  def cancel_buildroot_push
    change_mapping{|m| m.flags = m.flags - ['buildroot-push']}
  end

  def reselect_build
    extra_javascript 'brew_file_type_selector'

    set_page_title 'Reselect New Files for ' + @errata.fulladvisory
    @brew_build = @mapping.brew_build
    @current_types = @mapping.errata.build_mappings.where(:brew_build_id => @mapping.brew_build_id).
      map{|m| m.brew_archive_type.present? ? m.brew_archive_type.name : 'rpm'}.flatten.uniq.sort

    @content_types = build_content_types([@brew_build])
  end

  def save_reselect_build
    update_builds_from_errata(@errata, params[:builds]||{})
    render "save_builds"
  end

  def save_builds
    add_builds_to_errata(@errata, params[:builds]||{})

    if @errata.is_pdc?
      # For non-pdc advisories these are calculated inside the view
      # instead of here in the controller. See the partial files
      # _file_list and _file_list_pdc in app/views/shared.
      @bb_ids = Set.new
      @version_builds = HashList.new
      @no_listings = HashList.new
      @errata.pdc_errata_release_builds.each do |m|
        @bb_ids << m.brew_build_id
        @version_builds[m.pdc_release] << m
        @no_listings[m.pdc_release] << m.brew_build if !m.rpm_build_has_valid_listing?
      end
    end
  end

  def edit_file_meta
    extra_javascript %w[
      brew_edit_file_meta
      focus
      inline_editform
      lib/jquery.ui.sortable.min
      sortable_table
    ]
    extra_stylesheet %w[animate]
    @brew_file_meta = BrewFileMeta.find_or_init_for_advisory(@errata).reject{|m| m.brew_file.is_docker?}
  end

  def put_file_meta_title
    file = BrewFile.find(params[:file])

    meta = BrewFileMeta.find_or_init_for_advisory_and_file(@errata, file)
    meta.update_attributes!(:title => params[:title])

    new_html = partial_to_string('brew/brew_file_meta_inline_edit_title', :locals => {:meta => meta})
    render_js js_for_html "edit_title_for_file_#{file.id}", new_html, 'replaceWith'
  end

  def put_file_meta_rank
    file_order = params[:brew_file_order].split(',').map(&:to_i)

    BrewFileMeta.set_rank_for_advisory(@errata, file_order).each(&:save!)

    render :nothing => true, :status => 204
  end

  def ack_product_listings_mismatch
    mapping = ErrataBrewMapping.find(params[:id])
    mapping.update_attribute(:product_listings_mismatch_ack, true)

    redirect_to :action => 'list_files', :id => mapping.errata_id
  end

  private

  def change_mapping
    yield @mapping
    if @mapping.valid?
      @mapping.save!
    else
      show_error(@mapping.errors.full_messages)
    end
    redirect_to :action => 'list_files', :id => @errata
  end

  def build_content_types(brew_builds)
    brew_builds.map(&:selectable_brew_files).flatten.map(&:file_type_display).flatten.uniq.sort
  end

  def show_error(messages)
    set_flash_message(:error, messages)
  end

  def show_notice(messages)
    set_flash_message(:notice, messages)
  end

  def show_alert(messages)
    set_flash_message(:alert, messages)
  end

  def filelist_is_unlocked?
    return true if @errata.filelist_unlocked?
    flash_message :error, "Filelist is locked. State must be NEW_FILES to update builds"
    redirect_to :action => 'list_files', :id => @errata
    false
  end

  def find_build
    if params[:nvr]
      logger.warn "Looking for nvr"
      @build = BrewBuild.find_by_nvr(params[:nvr])
      return redirect_to_error!("No such build #{params[:nvr]}") unless @build
    else
      logger.warn "Looking for id"
      return redirect_to_error!("No such build #{params[:id]}") unless BrewBuild.exists?(params[:id])
      @build = BrewBuild.find params[:id]
    end
    true
  end

  def find_mapping
    mapping_id = params[:id]
    is_pdc = params[:is_pdc].to_bool
    @mapping = (is_pdc ? PdcErrataReleaseBuild : ErrataBrewMapping).find(mapping_id)
    @errata = @mapping.errata
  end

  # Finds a brew build by name or id
  def find_build_by_rpc(name_or_id, options={})
    name_or_id.chomp!
    if options[:cache_only]
      BrewBuild.find_by_id_or_nvr!(name_or_id)
    else
      BrewBuild.make_from_rpc_without_mandatory_srpm(name_or_id)
    end
  rescue => e
    msg = "Error retrieving build #{name_or_id}: " + e.message
    logger.warn msg
    logger.warn e.to_s
    @build_search_errors ||= HashList.new
    @build_search_errors[name_or_id] << msg
    if name_or_id =~ /\.rpm/
      @build_search_errors[name_or_id] << "You do not need the rpm file name, just the NVR. I.e. foobar-1.2.30 vs foobar-1.2.30.src.rpm."
    end
    nil
  end

  def brew_build_id_from_link(url)
    url =~ /http.*buildID\=(\d+)/ ? $1 : url
  end

  def build_names_from_text_field(text)
    return nil unless text
    build_names = text.split("\n").map(&:strip).reject(&:blank?).map{ |x| brew_build_id_from_link(x) }
    return nil if build_names.empty?
    RpmVersionCompare.find_newest_nvrs(build_names)
  end

  def for_builds_by_product_version
    out = Hash.new{|h,k| h[k] = HashList.new }

    direct_builds = []
    relations = []
    @errata.available_product_versions.each do |pv|
      build_names = build_names_from_text_field(params["pv_#{pv.id}"])
      next unless build_names

      # Some related builds may be selected implicitly
      related = build_names.
        map{|n| BrewBuildRelations.get_related(:errata => @errata, :nvr => n, :product_version => pv)}.
        flatten.uniq

      out[pv][:builds].concat(build_names)
      direct_builds.concat(build_names)
      relations.concat(related)
    end

    # process related builds, assigning them to the appropriate pv
    relations.each do |rel|
      next if rel.satisfied?

      pv = rel.related_product_version
      next unless @errata.available_product_versions.include?(pv)

      next if out[pv][:builds].include?(rel.related_nvr)

      out[pv][:build_relations] << rel
    end

    out.each do |pv,data|
      yield(pv, data[:builds], data[:build_relations])
    end
  end

  def for_builds_by_pdc_release
    out = Hash.new{|h,k| h[k] = HashList.new }

    @errata.available_pdc_releases.each do |pr|
      build_names = build_names_from_text_field(params["pv_#{pr.id}"])
      next unless build_names
      out[pr][:builds].concat(build_names)
    end

    # Since related builds are configured by product version,
    # currently PDC advisories do not support them.

    out.each do |pr, data|
      yield(pr, data[:builds], [])
    end
  end

  def allowed_to_request_buildroot_push
    validate_user_permission(:request_buildroot_push)
  end

  def allowed_to_cancel_buildroot_push
    validate_user_permission(:cancel_buildroot_push)
  end
end
